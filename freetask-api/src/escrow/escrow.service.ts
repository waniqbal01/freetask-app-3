import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { EscrowStatus, Job, JobStatus, Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type EscrowRecord = {
  id: number;
  jobId: number;
  status: EscrowStatus;
  amount: Prisma.Decimal | null;
  createdAt: Date;
  updatedAt: Date;
};

@Injectable()
export class EscrowService {
  private readonly logger = new Logger(EscrowService.name);

  constructor(private readonly prisma: PrismaService) { }

  async getForUser(jobId: number, userId: number, role: UserRole) {
    const { job, escrow } = await this.ensureEscrow(jobId);

    if (role !== UserRole.ADMIN && job.clientId !== userId && job.freelancerId !== userId) {
      throw new ForbiddenException('You are not allowed to view this escrow record');
    }

    return this.serializeEscrow(escrow);
  }

  async hold(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    const { job, escrow } = await this.ensureEscrow(jobId);

    this.ensureHoldAllowed(job.status);

    if (escrow.status !== EscrowStatus.PENDING) {
      throw new ConflictException('Escrow can only be held from the PENDING state');
    }

    const updated = await this.updateStatus(escrow.id, EscrowStatus.HELD);
    return this.serializeEscrow(updated);
  }

  async release(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    const { job, escrow } = await this.ensureEscrow(jobId);

    this.ensureReleaseOrRefundAllowed(job.status, 'release');

    if (escrow.status !== EscrowStatus.HELD) {
      throw new ConflictException('Escrow must be HELD before it can be released');
    }

    const updated = await this.updateStatus(escrow.id, EscrowStatus.RELEASED);
    return this.serializeEscrow(updated);
  }

  async refund(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    const { job, escrow } = await this.ensureEscrow(jobId);

    this.ensureReleaseOrRefundAllowed(job.status, 'refund');

    if (escrow.status !== EscrowStatus.HELD) {
      throw new ConflictException('Escrow must be HELD before it can be refunded');
    }

    const updated = await this.updateStatus(escrow.id, EscrowStatus.REFUNDED);
    return this.serializeEscrow(updated);
  }

  async syncOnJobStatus(
    tx: Prisma.TransactionClient,
    job: Pick<Job, 'id' | 'status' | 'amount'>,
    escrow: EscrowRecord,
  ) {
    const desiredStatus = this.resolveStatusForJob(job.status, escrow);

    if (!desiredStatus || desiredStatus === escrow.status) {
      return escrow;
    }

    this.logger.log(`Syncing escrow ${escrow.id} for job ${job.id} → ${desiredStatus}`);

    const updated = await tx.escrow.update({
      where: { id: escrow.id },
      data: { status: desiredStatus },
    });

    return updated as EscrowRecord;
  }

  private ensureAdmin(role: UserRole) {
    if (role !== UserRole.ADMIN) {
      throw new ForbiddenException('Only admins can perform this action');
    }
  }

  private ensureHoldAllowed(status: JobStatus) {
    const allowedStatuses = [JobStatus.PENDING, JobStatus.ACCEPTED, JobStatus.IN_PROGRESS];
    if (!allowedStatuses.includes(status)) {
      throw new ConflictException(
        `Escrow hold not allowed when job status is ${status.toString().toUpperCase()}`,
      );
    }
  }

  private ensureReleaseOrRefundAllowed(status: JobStatus, action: 'release' | 'refund') {
    const releaseAllowed = [JobStatus.COMPLETED, JobStatus.DISPUTED];
    const refundAllowed = [
      JobStatus.COMPLETED,
      JobStatus.DISPUTED,
      JobStatus.CANCELLED,
      JobStatus.REJECTED,
      JobStatus.ACCEPTED,
    ];

    const allowedSet = action === 'release' ? releaseAllowed : refundAllowed;

    if (!allowedSet.includes(status)) {
      const humanAction = action === 'release' ? 'released' : 'refunded';
      throw new ConflictException(
        `Escrow cannot be ${humanAction} when job status is ${status.toString().toUpperCase()}`,
      );
    }
  }

  private resolveStatusForJob(status: JobStatus, escrow: EscrowRecord): EscrowStatus | null {
    switch (status) {
      case JobStatus.COMPLETED: {
        // Validation: Cannot complete if already refunded/cancelled
        if ([EscrowStatus.REFUNDED, EscrowStatus.CANCELLED].includes(escrow.status)) {
          this.logger.warn(
            `Job completion blocked: Escrow already ${escrow.status} for escrow ${escrow.id}`,
          );
          return null;
        }
        if (escrow.status === EscrowStatus.RELEASED) {
          return null;
        }
        return EscrowStatus.RELEASED;
      }
      case JobStatus.CANCELLED:
      case JobStatus.REJECTED: {
        // Validation: Cannot cancel/reject if already released
        if (escrow.status === EscrowStatus.RELEASED) {
          this.logger.warn(
            `Job cancellation blocked: Escrow already released for escrow ${escrow.id}`,
          );
          return null;
        }
        if ([EscrowStatus.REFUNDED, EscrowStatus.CANCELLED].includes(escrow.status)) {
          return null;
        }
        return escrow.amount ? EscrowStatus.REFUNDED : EscrowStatus.CANCELLED;
      }
      case JobStatus.DISPUTED: {
        // Validation: Cannot dispute if already closed
        if ([EscrowStatus.RELEASED, EscrowStatus.REFUNDED].includes(escrow.status)) {
          this.logger.warn(
            `Job dispute blocked: Escrow already closed (${escrow.status}) for escrow ${escrow.id}`,
          );
          return null;
        }
        if (escrow.status === EscrowStatus.DISPUTED) {
          return null;
        }
        return EscrowStatus.DISPUTED;
      }
      default:
        return null;
    }
  }

  /**
   * Validates if a job status transition is allowed given the current escrow state.
   * Called BEFORE transaction to fail fast if escrow prevents the transition.
   * @returns Validation error message if invalid, null if allowed
   */
  validateJobTransition(
    job: Pick<Job, 'id' | 'status'>,
    escrow: EscrowRecord,
    newStatus: JobStatus,
  ): string | null {
    if (newStatus === JobStatus.COMPLETED) {
      if ([EscrowStatus.REFUNDED, EscrowStatus.CANCELLED].includes(escrow.status)) {
        return `Cannot complete job: escrow already ${escrow.status.toLowerCase()}`;
      }
    }

    if ([JobStatus.CANCELLED, JobStatus.REJECTED].includes(newStatus)) {
      if (escrow.status === EscrowStatus.RELEASED) {
        return 'Cannot cancel/reject job: escrow already released to freelancer';
      }
    }

    if (newStatus === JobStatus.DISPUTED) {
      if ([EscrowStatus.RELEASED, EscrowStatus.REFUNDED].includes(escrow.status)) {
        return `Cannot dispute job: escrow already ${escrow.status.toLowerCase()}`;
      }
    }

    return null;
  }

  private async ensureEscrow(jobId: number) {
    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) {
      throw new NotFoundException('Job not found');
    }

    const [existing] = await this.prisma.$queryRaw<EscrowRecord[]>`
      SELECT id, "jobId", status, amount, "createdAt", "updatedAt"
      FROM "Escrow"
      WHERE "jobId" = ${jobId}
      LIMIT 1
    `;

    if (existing) {
      return { job, escrow: existing };
    }

    await this.prisma.$executeRaw`
      INSERT INTO "Escrow" ("jobId", status, amount, "createdAt", "updatedAt")
      VALUES (${jobId}, 'PENDING', ${job.amount ?? null}, NOW(), NOW())
      ON CONFLICT ("jobId") DO NOTHING
    `;

    const [created] = await this.prisma.$queryRaw<EscrowRecord[]>`
      SELECT id, "jobId", status, amount, "createdAt", "updatedAt"
      FROM "Escrow"
      WHERE "jobId" = ${jobId}
      LIMIT 1
    `;

    if (!created) {
      throw new NotFoundException('Escrow record could not be created');
    }

    return { job, escrow: created };
  }

  private async updateStatus(escrowId: number, status: EscrowStatus) {
    await this.prisma.$executeRaw`
      UPDATE "Escrow"
      SET status = ${status}, "updatedAt" = NOW()
      WHERE id = ${escrowId}
    `;

    const [updated] = await this.prisma.$queryRaw<EscrowRecord[]>`
      SELECT id, "jobId", status, amount, "createdAt", "updatedAt"
      FROM "Escrow"
      WHERE id = ${escrowId}
      LIMIT 1
    `;

    if (!updated) {
      throw new NotFoundException('Escrow record not found');
    }

    return updated;
  }

  private serializeEscrow(escrow: EscrowRecord) {
    return {
      id: escrow.id,
      jobId: escrow.jobId,
      status: escrow.status,
      amount: escrow.amount ? Number(escrow.amount) : null,
      createdAt: escrow.createdAt,
      updatedAt: escrow.updatedAt,
    };
  }
}
