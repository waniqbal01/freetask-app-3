import {
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

@Injectable()
export class JobsService {
  constructor(private readonly prisma: PrismaService) {}

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

    const amount =
      dto.amount !== undefined ? new Prisma.Decimal(dto.amount) : service.price;

    const job = await this.prisma.job.create({
      data: {
        title: dto.title ?? service.title,
        description: dto.description,
        amount,
        serviceId: service.id,
        clientId: userId,
        freelancerId: service.freelancerId,
      },
      include: this.jobInclude,
    });

    return this.withFlatFields(job);
  }

  async findAllForUser(
    userId: number,
    filter?: 'client' | 'freelancer' | 'all',
  ) {
    const where: Prisma.JobWhereInput =
      filter === 'client'
        ? { clientId: userId }
        : filter === 'freelancer'
        ? { freelancerId: userId }
        : { OR: [{ clientId: userId }, { freelancerId: userId }] };

    const jobs = await this.prisma.job.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: this.jobInclude,
    });

    return jobs.map((job) => this.withFlatFields(job));
  }

  async findOneForUser(id: number, userId: number) {
    const job = await this.prisma.job.findFirst({
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

  async acceptJob(id: number, userId: number) {
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.ACCEPTED);
    return this.applyStatusUpdate(id, JobStatus.ACCEPTED);
  }

  async startJob(id: number, userId: number) {
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.IN_PROGRESS);
    return this.applyStatusUpdate(id, JobStatus.IN_PROGRESS);
  }

  async rejectJob(id: number, userId: number) {
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.REJECTED);
    return this.applyStatusUpdate(id, JobStatus.REJECTED);
  }

  async cancelJob(id: number, userId: number) {
    const job = await this.ensureJobForClient(id, userId);
    this.ensureValidTransition(job.status, JobStatus.CANCELLED);
    return this.applyStatusUpdate(id, JobStatus.CANCELLED);
  }

  async completeJob(id: number, userId: number) {
    const job = await this.ensureJobParticipant(id, userId);
    this.ensureValidTransition(job.status, JobStatus.COMPLETED);
    return this.applyStatusUpdate(id, JobStatus.COMPLETED);
  }

  async disputeJob(id: number, userId: number, dto: DisputeJobDto) {
    const job = await this.ensureJobParticipant(id, userId);
    this.ensureValidTransition(job.status, JobStatus.DISPUTED);
    return this.applyStatusUpdate(id, JobStatus.DISPUTED, dto.reason);
  }

  async updateStatus(
    id: number,
    userId: number,
    role: UserRole,
    dto: UpdateJobStatusDto,
  ) {
    if (role !== UserRole.FREELANCER) {
      throw new ForbiddenException('Only freelancers can update job status');
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
      throw new ConflictException(
        `Invalid status transition: ${current} -> ${next}`,
      );
    }
  }

  private applyStatusUpdate(id: number, status: JobStatus, disputeReason?: string) {
    return this.prisma.job
      .update({
        where: { id },
        data: {
          status,
          disputeReason: disputeReason ?? null,
        },
        include: this.jobInclude,
      })
      .then((job) => this.withFlatFields(job));
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
