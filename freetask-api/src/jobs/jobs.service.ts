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
import { ChatsGateway } from '../chats/chats.gateway';
import { NotificationsService } from '../notifications/notifications.service';

type JobWithRelations = Prisma.JobGetPayload<{
  include: {
    service: { select: { id: true; title: true } };
    client: { select: { id: true; name: true } };
    freelancer: { select: { id: true; name: true } };
  };
}>;

@Injectable()
export class JobsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly chatsGateway: ChatsGateway,
    private readonly notificationsService: NotificationsService,
  ) {}

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
    if (!service.active) {
      throw new ForbiddenException('Servis ini tidak lagi aktif');
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

    await this.recordHistory(job.id, userId, 'JOB_CREATED', 'Job dicipta oleh client');

    await this.notificationsService.notifyUser(
      job.freelancerId,
      'JOB_CREATED',
      'Job baharu diterima',
      `${job.client.name} menempah ${job.service.title}.`,
      { jobId: job.id, serviceId: job.service.id },
    );

    return job;
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

  async acceptJob(id: number, userId: number, role: UserRole) {
    if (role !== UserRole.CLIENT) {
      throw new ForbiddenException('Only clients can accept jobs');
    }

    const job = await this.ensureJobForClient(id, userId);
    this.ensureValidTransition(job.status, JobStatus.ACCEPTED);
    return this.applyStatusUpdate(id, JobStatus.ACCEPTED, userId, 'JOB_ACCEPTED');
  }

  async startJob(id: number, userId: number) {
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.IN_PROGRESS);
    return this.applyStatusUpdate(id, JobStatus.IN_PROGRESS, userId, 'JOB_STARTED');
  }

  async rejectJob(id: number, userId: number) {
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.REJECTED);
    return this.applyStatusUpdate(id, JobStatus.REJECTED, userId, 'JOB_REJECTED');
  }

  async completeJob(id: number, userId: number) {
    const job = await this.ensureJobParticipant(id, userId);
    this.ensureValidTransition(job.status, JobStatus.COMPLETED);
    return this.applyStatusUpdate(id, JobStatus.COMPLETED, userId, 'JOB_COMPLETED');
  }

  async disputeJob(id: number, userId: number, dto: DisputeJobDto) {
    const job = await this.ensureJobParticipant(id, userId);
    this.ensureValidTransition(job.status, JobStatus.DISPUTED);
    return this.applyStatusUpdate(
      id,
      JobStatus.DISPUTED,
      userId,
      'JOB_DISPUTED',
      dto.reason,
    );
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
    return this.applyStatusUpdate(id, dto.status, userId);
  }

  private ensureValidTransition(current: JobStatus, next: JobStatus) {
    const transitions: Record<JobStatus, JobStatus[]> = {
      [JobStatus.PENDING]: [JobStatus.ACCEPTED, JobStatus.REJECTED],
      [JobStatus.ACCEPTED]: [
        JobStatus.IN_PROGRESS,
        JobStatus.CANCELLED,
        JobStatus.DISPUTED,
      ],
      [JobStatus.IN_PROGRESS]: [
        JobStatus.COMPLETED,
        JobStatus.CANCELLED,
        JobStatus.DISPUTED,
      ],
      [JobStatus.COMPLETED]: [JobStatus.DISPUTED],
      [JobStatus.CANCELLED]: [],
      [JobStatus.REJECTED]: [],
      [JobStatus.DISPUTED]: [],
    };

    const allowedNextStates = transitions[current] ?? [];
    if (!allowedNextStates.includes(next)) {
      throw new ConflictException(
        `Cannot change job status from ${current} to ${next}`,
      );
    }
  }

  private async applyStatusUpdate(
    id: number,
    status: JobStatus,
    actorId?: number,
    action?: string,
    disputeReason?: string,
  ) {
    const job = await this.prisma.job.update({
      where: { id },
      data: {
        status,
        disputeReason: disputeReason ?? null,
      },
      include: this.jobInclude,
    });

    this.chatsGateway.emitJobStatusUpdate(job);
    await this.notifyParticipantsOfStatus(job);

    const derivedAction =
      action ??
      this.mapActionFromStatus(status, {
        previousReason: disputeReason,
      });
    await this.recordHistory(job.id, actorId, derivedAction, disputeReason);

    return job;
  }

  async getJobHistory(jobId: number, userId: number, role: UserRole) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      select: {
        clientId: true,
        freelancerId: true,
      },
    });

    if (!job) {
      throw new NotFoundException('Job not found');
    }

    if (
      role !== UserRole.ADMIN &&
      job.clientId !== userId &&
      job.freelancerId !== userId
    ) {
      throw new ForbiddenException('Anda tidak mempunyai akses ke job ini');
    }

    return this.prisma.jobHistory.findMany({
      where: { jobId },
      orderBy: { createdAt: 'asc' },
      include: {
        actor: { select: { id: true, name: true } },
      },
    });
  }

  private mapActionFromStatus(status: JobStatus, context?: { previousReason?: string }) {
    if (status === JobStatus.DISPUTED && context?.previousReason) {
      return 'JOB_DISPUTED';
    }
    if (status === JobStatus.COMPLETED) {
      return 'JOB_COMPLETED';
    }
    if (status === JobStatus.IN_PROGRESS) {
      return 'JOB_STARTED';
    }
    if (status === JobStatus.ACCEPTED) {
      return 'JOB_ACCEPTED';
    }
    if (status === JobStatus.CANCELLED) {
      return 'JOB_REJECTED';
    }
    return 'JOB_STATUS_UPDATED';
  }

  private async recordHistory(
    jobId: number,
    actorId: number | undefined,
    action: string,
    message?: string,
  ) {
    await this.prisma.jobHistory.create({
      data: {
        jobId,
        actorId,
        action,
        message,
      },
    });
  }

  private async ensureJobForClient(id: number, userId: number) {
    const job = await this.prisma.job.findUnique({ where: { id } });
    if (!job) {
      throw new NotFoundException('Job not found');
    }
    if (job.clientId !== userId) {
      throw new ForbiddenException('Only job owner can perform this action');
    }
    return job;
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

  private async notifyParticipantsOfStatus(job: JobWithRelations) {
    const metadata = {
      jobId: job.id,
      status: job.status,
      disputeReason: job.disputeReason,
    };
    const body = this.buildStatusBody(job);
    const title = `Status job ${job.title}`;

    await Promise.all(
      [job.clientId, job.freelancerId]
        .filter((value, index, array) => array.indexOf(value) === index)
        .map((userId) =>
          this.notificationsService.notifyUser(
            userId,
            'JOB_STATUS_UPDATED',
            title,
            body,
            metadata,
            { queueEmail: true },
          ),
        ),
    );
  }

  private buildStatusBody(job: JobWithRelations): string {
    const statusCopy: Record<JobStatus, string> = {
      [JobStatus.PENDING]: 'menunggu pengesahan',
      [JobStatus.ACCEPTED]: 'telah diterima',
      [JobStatus.IN_PROGRESS]: 'sedang dijalankan',
      [JobStatus.COMPLETED]: 'telah siap',
      [JobStatus.CANCELLED]: 'telah dibatalkan',
      [JobStatus.REJECTED]: 'telah ditolak',
      [JobStatus.DISPUTED]: 'dalam pertikaian',
    };

    const base = statusCopy[job.status] ?? job.status.toLowerCase();
    if (job.status === JobStatus.DISPUTED && job.disputeReason) {
      return `Job ${job.title} ${base}. Sebab: ${job.disputeReason}`;
    }
    return `Job ${job.title} ${base}.`;
  }
}
