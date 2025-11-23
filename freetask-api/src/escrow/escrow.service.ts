import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
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
    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) {
      throw new NotFoundException('Job not found');
    }

    if (role !== UserRole.ADMIN && job.clientId !== userId && job.freelancerId !== userId) {
      throw new ForbiddenException('You are not allowed to view this escrow record');
    }

    const escrow = await this.ensureEscrow(job.id, job.amount ?? null);
    return this.serializeEscrow(escrow);
  }

  async hold(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    const escrow = await this.ensureEscrow(jobId);

    if (escrow.status !== 'PENDING') {
      throw new ConflictException('Escrow can only be held from the PENDING state');
    }

    const updated = await this.updateStatus(escrow.id, 'HELD');
    return this.serializeEscrow(updated);
  }

  async release(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    const escrow = await this.ensureEscrow(jobId);

    if (escrow.status !== 'HELD') {
      throw new ConflictException('Escrow must be HELD before it can be released');
    }

    const updated = await this.updateStatus(escrow.id, 'RELEASED');
    return this.serializeEscrow(updated);
  }

  async refund(jobId: number, role: UserRole) {
    this.ensureAdmin(role);
    const escrow = await this.ensureEscrow(jobId);

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

  private async ensureEscrow(jobId: number, amount?: Prisma.Decimal | null) {
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
      return existing;
    }

    await this.prisma.$executeRaw`
      INSERT INTO "Escrow" ("jobId", status, amount, "createdAt", "updatedAt")
      VALUES (${jobId}, 'PENDING', ${amount ?? job.amount ?? null}, NOW(), NOW())
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

    return created;
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
