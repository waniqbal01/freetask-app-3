import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { JobStatus, Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateJobDto } from './dto/create-job.dto';
import { DisputeJobDto } from './dto/dispute-job.dto';
import { UpdateJobStatusDto } from './dto/update-job-status.dto';
import { JOB_MIN_DISPUTE_REASON_LEN } from './constants';
import { EscrowService } from '../escrow/escrow.service';

@Injectable()
export class JobsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly escrowService: EscrowService,
  ) { }

  async create(userId: number, role: UserRole, dto: CreateJobDto) {
    if (role !== UserRole.CLIENT) {
      throw new ForbiddenException('Only clients can create jobs');
    }

    const service = await this.prisma.service.findUnique({
      where: { id: dto.serviceId },
    });
    if (!service) {
      throw new NotFoundException('Service not found');
    }

    const parsedAmount = Number(dto.amount);
    if (!Number.isFinite(parsedAmount)) {
      throw new BadRequestException('amount must be a valid number');
    }
    const amount = new Prisma.Decimal(parsedAmount.toFixed(2));

    // Trim title to prevent whitespace inconsistencies
    const trimmedTitle = (dto.title ?? service.title).trim();

    const job = await this.prisma.job.create({
      data: {
        title: trimmedTitle,
        description: dto.description,
        amount,
        serviceId: service.id,
        clientId: userId,
        freelancerId: service.freelancerId,
      },
      include: this.jobInclude,
    });

    await this.createEscrowRecord(job.id, amount);

    return this.withFlatFields(job);
  }

  async findAllForUser(
    userId: number,
    role: UserRole,
    filter?: 'client' | 'freelancer' | 'all',
    pagination?: { limit?: number; offset?: number },
  ) {
    const effectiveFilter = role === UserRole.ADMIN && !filter ? 'all' : filter;

    if (effectiveFilter === 'all' && role !== UserRole.ADMIN) {
      throw new ForbiddenException('Only admins can view all jobs');
    }

    const normalizedFilter =
      effectiveFilter ??
      (role === UserRole.CLIENT ? 'client' : role === UserRole.FREELANCER ? 'freelancer' : 'all');

    const where: Prisma.JobWhereInput =
      normalizedFilter === 'client'
        ? { clientId: userId }
        : normalizedFilter === 'freelancer'
          ? { freelancerId: userId }
          : role === UserRole.ADMIN
            ? {}
            : { OR: [{ clientId: userId }, { freelancerId: userId }] };

    const take = Math.min(Math.max(pagination?.limit ?? 20, 1), 50);
    const skip = Math.max(pagination?.offset ?? 0, 0);

    const jobs = await this.prisma.job.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: this.jobInclude,
      take,
      skip,
    });

    return jobs.map((job) => this.withFlatFields(job));
  }

  async findOneForUser(id: number, userId: number, role: UserRole) {
    const job =
      role === UserRole.ADMIN
        ? await this.prisma.job.findUnique({ where: { id }, include: this.jobInclude })
        : await this.prisma.job.findFirst({
          where: {
            id,
            OR: [{ clientId: userId }, { freelancerId: userId }],
          },
          include: this.jobInclude,
        });
    if (!job) {
      throw new NotFoundException('Job not found');
    }
    return this.withFlatFields(job);
  }

  async acceptJob(id: number, userId: number, role: UserRole) {
    this.ensureRole(role, [UserRole.FREELANCER]);
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.ACCEPTED);
    return this.applyStatusUpdate(id, JobStatus.ACCEPTED);
  }

  async startJob(id: number, userId: number, role: UserRole) {
    this.ensureRole(role, [UserRole.FREELANCER]);
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.IN_PROGRESS);
    return this.applyStatusUpdate(id, JobStatus.IN_PROGRESS);
  }

  async rejectJob(id: number, userId: number, role: UserRole) {
    this.ensureRole(role, [UserRole.FREELANCER]);
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.REJECTED);
    return this.applyStatusUpdate(id, JobStatus.REJECTED);
  }

  async cancelJob(id: number, userId: number, role: UserRole) {
    this.ensureRole(role, [UserRole.CLIENT]);
    const job = await this.ensureJobForClient(id, userId);
    this.ensureValidTransition(job.status, JobStatus.CANCELLED);
    return this.applyStatusUpdate(id, JobStatus.CANCELLED);
  }

  async completeJob(id: number, userId: number, role: UserRole) {
    this.ensureRole(role, [UserRole.FREELANCER]);
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.COMPLETED);
    return this.applyStatusUpdate(id, JobStatus.COMPLETED);
  }

  async disputeJob(id: number, userId: number, role: UserRole, dto: DisputeJobDto) {
    this.ensureRole(role, [UserRole.FREELANCER, UserRole.CLIENT]);
    const job = await this.ensureJobParticipant(id, userId);
    this.ensureValidTransition(job.status, JobStatus.DISPUTED);

    // Enforce 7-day dispute window for COMPLETED jobs
    if (job.status === JobStatus.COMPLETED) {
      const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
      const timeSinceCompletion = Date.now() - job.updatedAt.getTime();
      if (timeSinceCompletion > sevenDaysMs) {
        throw new ForbiddenException(
          'Dispute period has expired (7 days after completion).',
        );
      }
    }

    const trimmedReason = dto.reason?.trim() ?? '';
    if (trimmedReason.length < JOB_MIN_DISPUTE_REASON_LEN) {
      throw new BadRequestException(
        `Dispute reason must be at least ${JOB_MIN_DISPUTE_REASON_LEN} characters.`,
      );
    }
    return this.applyStatusUpdate(id, JobStatus.DISPUTED, trimmedReason);
  }

  async updateStatus(
    id: number,
    userId: number,
    role: UserRole,
    dto: UpdateJobStatusDto,
  ) {
    this.ensureRole(role, [UserRole.FREELANCER]);

    if (dto.status === JobStatus.CANCELLED) {
      throw new ForbiddenException('Freelancers cannot cancel jobs');
    }

    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, dto.status);
    return this.applyStatusUpdate(id, dto.status);
  }

  private ensureValidTransition(current: JobStatus, next: JobStatus) {
    const transitions: Record<JobStatus, JobStatus[]> = {
      [JobStatus.PENDING]: [JobStatus.ACCEPTED, JobStatus.REJECTED, JobStatus.CANCELLED],
      [JobStatus.ACCEPTED]: [JobStatus.IN_PROGRESS, JobStatus.CANCELLED],
      [JobStatus.IN_PROGRESS]: [
        JobStatus.COMPLETED,
        JobStatus.CANCELLED,
        JobStatus.DISPUTED,
      ],
      [JobStatus.COMPLETED]: [JobStatus.DISPUTED],
      [JobStatus.CANCELLED]: [],
      [JobStatus.REJECTED]: [JobStatus.CANCELLED],
      [JobStatus.DISPUTED]: [],
    };

    const allowedNextStates = transitions[current] ?? [];
    if (!allowedNextStates.includes(next)) {
      throw new ConflictException('Invalid status transition');
    }
  }

  private ensureRole(role: UserRole, allowed: UserRole[]) {
    if (!allowed.includes(role)) {
      throw new ForbiddenException('Role tidak dibenarkan untuk tindakan ini.');
    }
  }

  private applyStatusUpdate(id: number, status: JobStatus, disputeReason?: string) {
    return this.prisma.$transaction(async (tx) => {
      // Fetch job and escrow BEFORE making any changes
      const existingJob = await tx.job.findUnique({ where: { id } });
      if (!existingJob) {
        throw new NotFoundException('Job not found');
      }

      // BLOCKER #3 FIX: Validate escrow allows transition BEFORE updating job
      const escrow = await tx.escrow.findUnique({ where: { jobId: id } });
      if (escrow) {
        const validationError = this.escrowService.validateJobTransition(
          existingJob,
          escrow,
          status,
        );
        if (validationError) {
          throw new ConflictException(validationError);
        }
      }

      // Now safe to update job status
      const job = await tx.job.update({
        where: { id },
        data: {
          status,
          disputeReason: disputeReason ?? null,
        },
        include: this.jobInclude,
      });

      // Sync escrow status (this should no longer throw)
      if (escrow) {
        await this.escrowService.syncOnJobStatus(tx, job, escrow);
      }

      return this.withFlatFields(job);
    });
  }

  private async createEscrowRecord(jobId: number, amount?: Prisma.Decimal | null) {
    await this.prisma.$executeRaw`
      INSERT INTO "Escrow" ("jobId", status, amount, "createdAt", "updatedAt")
      VALUES (${jobId}, 'PENDING', ${amount ?? null}, NOW(), NOW())
      ON CONFLICT ("jobId") DO NOTHING
    `;
  }

  private async ensureJobForFreelancer(id: number, userId: number) {
    const job = await this.prisma.job.findUnique({ where: { id } });
    if (!job) {
      throw new NotFoundException('Job not found');
    }
    if (job.freelancerId !== userId) {
      throw new ForbiddenException('Only assigned freelancer can perform this action');
    }
    return job;
  }

  private async ensureJobForClient(id: number, userId: number) {
    const job = await this.prisma.job.findUnique({ where: { id } });
    if (!job) {
      throw new NotFoundException('Job not found');
    }
    if (job.clientId !== userId) {
      throw new ForbiddenException('Only the client can perform this action');
    }
    return job;
  }

  private async ensureJobParticipant(id: number, userId: number) {
    const job = await this.prisma.job.findUnique({ where: { id } });
    if (!job) {
      throw new NotFoundException('Job not found');
    }
    if (job.clientId !== userId && job.freelancerId !== userId) {
      throw new ForbiddenException('You are not part of this job');
    }
    return job;
  }

  private get jobInclude() {
    return {
      service: {
        select: { id: true, title: true },
      },
      client: {
        select: { id: true, name: true },
      },
      freelancer: {
        select: { id: true, name: true },
      },
    } as const;
  }

  private withFlatFields<
    T extends {
      service?: { id: number; title: string } | null;
      client?: { id: number; name: string } | null;
      freelancer?: { id: number; name: string } | null;
      clientId?: number;
      freelancerId?: number;
    },
  >(job: T) {
    return {
      ...job,
      serviceTitle: job.service?.title ?? null,
      clientId: job.client?.id ?? job.clientId ?? null,
      freelancerId: job.freelancer?.id ?? job.freelancerId ?? null,
    };
  }
}
