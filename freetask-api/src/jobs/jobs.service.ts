import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { JobStatus, Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateJobDto } from './dto/create-job.dto';
import { DisputeJobDto } from './dto/dispute-job.dto';

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

    return this.prisma.job.create({
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

    return this.prisma.job.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: this.jobInclude,
    });
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
    return job;
  }

  async acceptJob(id: number, userId: number) {
    // Kept for backward compatibility; delegates to startJob to use new status flow.
    return this.startJob(id, userId);
  }

  async startJob(id: number, userId: number) {
    const job = await this.ensureJobForFreelancer(id, userId);
    if (job.status !== JobStatus.PENDING) {
      throw new ForbiddenException('Only pending jobs can be started');
    }
    return this.updateStatus(id, JobStatus.IN_PROGRESS);
  }

  async rejectJob(id: number, userId: number) {
    const job = await this.ensureJobForFreelancer(id, userId);
    if (job.status !== JobStatus.PENDING) {
      throw new ForbiddenException('Only pending jobs can be rejected');
    }
    return this.updateStatus(id, JobStatus.REJECTED);
  }

  async completeJob(id: number, userId: number) {
    const job = await this.ensureJobParticipant(id, userId);
    if (job.status !== JobStatus.IN_PROGRESS) {
      throw new ForbiddenException('Only in-progress jobs can be completed');
    }
    return this.updateStatus(id, JobStatus.COMPLETED);
  }

  async disputeJob(id: number, userId: number, dto: DisputeJobDto) {
    await this.ensureJobParticipant(id, userId);
    return this.prisma.job.update({
      where: { id },
      data: {
        status: JobStatus.DISPUTED,
        disputeReason: dto.reason,
      },
      include: this.jobInclude,
    });
  }

  private updateStatus(id: number, status: JobStatus) {
    return this.prisma.job.update({
      where: { id },
      data: { status },
      include: this.jobInclude,
    });
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
}
