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

  // Admin/Controller facing methods with checks
  async hold(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    return this.internalHold(jobId);
  }

  async release(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    return this.internalRelease(jobId);
  }

  async refund(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    return this.internalRefund(jobId);
  }

  // Internal System methods (skip role checks)
  async internalHold(jobId: number) {
    const { job, escrow } = await this.ensureEscrow(jobId);
    this.ensureHoldAllowed(job.status);

    if (escrow.status !== EscrowStatus.PENDING) {
      // If already held (e.g. by webhook race condition), just return it
      if (escrow.status === EscrowStatus.HELD) return this.serializeEscrow(escrow);
      throw new ConflictException('Escrow can only be held from the PENDING state');
    }

    const updated = await this.updateStatus(escrow.id, EscrowStatus.HELD);
    return this.serializeEscrow(updated);
  }

  async internalRelease(jobId: number) {
    const { job, escrow } = await this.ensureEscrow(jobId);
    this.ensureReleaseOrRefundAllowed(job.status, 'release');

    if (escrow.status !== EscrowStatus.HELD) {
      throw new ConflictException('Escrow must be HELD before it can be released');
    }

    // Transaction: Update Escrow -> Credit Freelancer
    const result = await this.prisma.$transaction(async (tx) => {
      const updatedEscrow = await tx.escrow.update({
        where: { id: escrow.id },
        data: { status: EscrowStatus.RELEASED, updatedAt: new Date() }
      });

      // Credit freelancer balance
      if (escrow.amount && Number(escrow.amount) > 0) {
        await tx.user.update({
          where: { id: job.freelancerId },
          data: { balance: { increment: escrow.amount } }
        });
      }

      return updatedEscrow;
    });

    return this.serializeEscrow(result as EscrowRecord);
  }

  async internalRefund(jobId: number) {
    const { job, escrow } = await this.ensureEscrow(jobId);
    this.ensureReleaseOrRefundAllowed(job.status, 'refund');

    if (escrow.status !== EscrowStatus.HELD) {
      // Allow refunding even if PENDING? Usually refunds happen after payment (HELD).
      // If PENDING, maybe just cancel? But let's stick to HELD for now.
      throw new ConflictException('Escrow must be HELD before it can be refunded');
    }

    // Transaction: Update Escrow -> Credit Client (Refund to wallet)
    const result = await this.prisma.$transaction(async (tx) => {
      const updatedEscrow = await tx.escrow.update({
        where: { id: escrow.id },
        data: { status: EscrowStatus.REFUNDED, updatedAt: new Date() }
      });

      // Credit client balance (internal refund)
      if (escrow.amount && Number(escrow.amount) > 0) {
        await tx.user.update({
          where: { id: job.clientId },
          data: { balance: { increment: escrow.amount } }
        });
      }

      return updatedEscrow;
    });

    return this.serializeEscrow(result as EscrowRecord);
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

    // If syncing leads to RELEASE or REFUND, we should probably trigger the internal logic to ensure balance update.
    // However, syncOnJobStatus is likely called WITHIN a transaction that updates Job status.
    // So we just update the escrow status here, BUT we need to make sure balance is updated too.
    // This methods seems to be a "passive" sync. 
    // REVISIT: If this is passive sync, we might miss balance updates if we just change status.
    // For now, let's assume specific actions (Complete Job etc) will call internalRelease explicitely.
    // If this sync is just for consistency, we log it.

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
    const allowedStatuses: JobStatus[] = [JobStatus.PENDING, JobStatus.ACCEPTED, JobStatus.IN_PROGRESS];
    if (!allowedStatuses.includes(status)) {
      throw new ConflictException(
        `Escrow hold not allowed when job status is ${status.toString().toUpperCase()}`,
      );
    }
  }

  private ensureReleaseOrRefundAllowed(status: JobStatus, action: 'release' | 'refund') {
    const releaseAllowed: JobStatus[] = [JobStatus.COMPLETED, JobStatus.DISPUTED];
    const refundAllowed: JobStatus[] = [
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
        if (([EscrowStatus.REFUNDED, EscrowStatus.CANCELLED] as EscrowStatus[]).includes(escrow.status)) {
          return null;
        }
        if (escrow.status === EscrowStatus.RELEASED) {
          return null;
        }
        return EscrowStatus.RELEASED;
      }
      case JobStatus.CANCELLED:
      case JobStatus.REJECTED: {
        if (escrow.status === EscrowStatus.RELEASED) {
          return null;
        }
        if (([EscrowStatus.REFUNDED, EscrowStatus.CANCELLED] as EscrowStatus[]).includes(escrow.status)) {
          return null;
        }
        return escrow.amount ? EscrowStatus.REFUNDED : EscrowStatus.CANCELLED;
      }
      case JobStatus.DISPUTED: {
        if (([EscrowStatus.RELEASED, EscrowStatus.REFUNDED] as EscrowStatus[]).includes(escrow.status)) {
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

  validateJobTransition(
    job: Pick<Job, 'id' | 'status'>,
    escrow: EscrowRecord,
    newStatus: JobStatus,
  ): string | null {
    if (newStatus === JobStatus.COMPLETED) {
      if (([EscrowStatus.REFUNDED, EscrowStatus.CANCELLED] as EscrowStatus[]).includes(escrow.status)) {
        return `Cannot complete job: escrow already ${escrow.status.toLowerCase()}`;
      }
    }

    if (([JobStatus.CANCELLED, JobStatus.REJECTED] as JobStatus[]).includes(newStatus)) {
      if (escrow.status === EscrowStatus.RELEASED) {
        return 'Cannot cancel/reject job: escrow already released to freelancer';
      }
    }

    if (newStatus === JobStatus.DISPUTED) {
      if (([EscrowStatus.RELEASED, EscrowStatus.REFUNDED] as EscrowStatus[]).includes(escrow.status)) {
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
      // Handle potential Decimal string conversion or number
      amount: escrow.amount ? Number(escrow.amount) : null,
      createdAt: escrow.createdAt,
      updatedAt: escrow.updatedAt,
    };
  }
}

