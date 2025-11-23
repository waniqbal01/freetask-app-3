import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { JobStatus, Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const ESCROW_STATUS = ['PENDING', 'HELD', 'RELEASED', 'REFUNDED'] as const;
type EscrowStatus = (typeof ESCROW_STATUS)[number];

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
  constructor(private readonly prisma: PrismaService) {}

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

    if (escrow.status !== 'PENDING') {
      throw new ConflictException('Escrow can only be held from the PENDING state');
    }

    const updated = await this.updateStatus(escrow.id, 'HELD');
    return this.serializeEscrow(updated);
  }

  async release(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    const { job, escrow } = await this.ensureEscrow(jobId);

    this.ensureReleaseOrRefundAllowed(job.status, 'release');

    if (escrow.status !== 'HELD') {
      throw new ConflictException('Escrow must be HELD before it can be released');
    }

    const updated = await this.updateStatus(escrow.id, 'RELEASED');
    return this.serializeEscrow(updated);
  }

  async refund(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    const { job, escrow } = await this.ensureEscrow(jobId);

    this.ensureReleaseOrRefundAllowed(job.status, 'refund');

    if (escrow.status !== 'HELD') {
      throw new ConflictException('Escrow must be HELD before it can be refunded');
    }

    const updated = await this.updateStatus(escrow.id, 'REFUNDED');
    return this.serializeEscrow(updated);
  }

  private ensureAdmin(role: UserRole) {
    if (role !== UserRole.ADMIN) {
      throw new ForbiddenException('Only admins can perform this action');
    }
  }

  private ensureHoldAllowed(status: JobStatus) {
    if (![JobStatus.ACCEPTED, JobStatus.IN_PROGRESS].includes(status)) {
      throw new ConflictException('Escrow hold requires job to be ACCEPTED or IN_PROGRESS');
    }
  }

  private ensureReleaseOrRefundAllowed(status: JobStatus, action: 'release' | 'refund') {
    if (![JobStatus.COMPLETED, JobStatus.DISPUTED].includes(status)) {
      const message =
        action === 'release'
          ? 'Escrow can only be released when the job is COMPLETED or DISPUTED'
          : 'Escrow can only be refunded when the job is COMPLETED or DISPUTED';
      throw new ConflictException(message);
    }
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
