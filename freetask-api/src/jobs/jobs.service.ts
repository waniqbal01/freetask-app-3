import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { JobStatus, Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateJobDto } from './dto/create-job.dto';
import { DisputeJobDto } from './dto/dispute-job.dto';
import { UpdateJobStatusDto } from './dto/update-job-status.dto';
import { SubmitJobDto } from './dto/submit-job.dto';
import { RequestRevisionDto } from './dto/request-revision.dto';
import { JOB_MIN_DISPUTE_REASON_LEN } from './constants';
import { EscrowService } from '../escrow/escrow.service';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NotificationsService } from '../notifications/notifications.service';
import { ChatsService } from '../chats/chats.service';

@Injectable()
export class JobsService {
  private readonly logger = new Logger(JobsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly escrowService: EscrowService,
    private readonly notificationsService: NotificationsService,
    private readonly chatsService: ChatsService,
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
        orderAttachments: dto.attachments ? (dto.attachments as any) : undefined,
      },
      include: this.jobInclude,
    });

    await this.createEscrowRecord(job.id, amount);

    // Notify Freelancer
    await this.notificationsService.sendNotification({
      userId: service.freelancerId,
      title: 'New Order Received',
      body: `You have received a new order: ${trimmedTitle}`,
      data: { type: 'job_order', jobId: job.id.toString() },
    });

    return this.withFlatFields(job);
  }

  async findAllForUser(
    userId: number,
    role: UserRole,
    filter?: 'client' | 'freelancer' | 'all',
    status?: string,
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

    if (status) {
      const statuses = status.split(',') as JobStatus[];
      (where as any).status = { in: statuses };
    }

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
    this.ensureValidTransition(job.status, JobStatus.IN_PROGRESS);

    // Notify Client
    await this.notificationsService.sendNotification({
      userId: job.clientId,
      title: 'Order Accepted & Started',
      body: `Freelancer has accepted and started your order #${job.id}`,
      data: { type: 'job_started', jobId: job.id.toString() },
    });

    return this.applyStatusUpdate(id, JobStatus.IN_PROGRESS);
  }

  async startJob(id: number, userId: number, role: UserRole) {
    this.ensureRole(role, [UserRole.FREELANCER]);
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.IN_PROGRESS);

    // Notify Client
    await this.notificationsService.sendNotification({
      userId: job.clientId,
      title: 'Job Started',
      body: `Freelancer has started working on job #${job.id}`,
      data: { type: 'job_started', jobId: job.id.toString() },
    });

    return this.applyStatusUpdate(id, JobStatus.IN_PROGRESS);
  }

  async submitJob(id: number, userId: number, role: UserRole, dto: SubmitJobDto) {
    this.ensureRole(role, [UserRole.FREELANCER]);
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.IN_REVIEW);

    const now = new Date();
    const autoCompleteAt = new Date(now.getTime() + 48 * 60 * 60 * 1000); // 48 hours from now

    const updatedJob = await this.prisma.$transaction(async (tx) => {
      const j = await tx.job.update({
        where: { id },
        data: {
          status: JobStatus.IN_REVIEW,
          submittedAt: now,
          autoCompleteAt: autoCompleteAt,
          submissionMessage: dto.message,
          submissionAttachments: dto.attachments ? (dto.attachments as any) : undefined,
        },
        include: this.jobInclude,
      });
      return j;
    });

    // Notify Client
    await this.notificationsService.sendNotification({
      userId: job.clientId,
      title: 'Job Submitted for Review',
      body: `Freelancer has submitted work for Job #${job.id}. Please review within 48 hours.`,
      data: { type: 'job_submitted', jobId: job.id.toString() },
    });

    // System Message in Chat
    await this.chatsService.postMessage(id, userId, role, {
      content: `[SYSTEM] Work submitted: ${dto.message || 'No description provided.'}`,
      type: 'system',
    });

    return this.withFlatFields(updatedJob);
  }

  async confirmJob(id: number, userId: number, role: UserRole) {
    this.ensureRole(role, [UserRole.CLIENT]);
    const job = await this.ensureJobForClient(id, userId);
    this.ensureValidTransition(job.status, JobStatus.COMPLETED);

    const updatedJob = await this.applyStatusUpdate(id, JobStatus.COMPLETED);

    // Notify Freelancer
    await this.notificationsService.sendNotification({
      userId: job.freelancerId,
      title: 'Job Completed',
      body: `Client confirmed completion for Job #${job.id}. Funds released.`,
      data: { type: 'job_completed', jobId: job.id.toString() },
    });

    // System Message
    await this.chatsService.postMessage(id, userId, role, {
      content: '[SYSTEM] Job marked as completed by client.',
      type: 'system',
    });

    return updatedJob;
  }

  async requestRevision(id: number, userId: number, role: UserRole, dto: RequestRevisionDto) {
    this.ensureRole(role, [UserRole.CLIENT]);
    const job = await this.ensureJobForClient(id, userId);
    this.ensureValidTransition(job.status, JobStatus.IN_PROGRESS);

    // Reset auto complete
    const updatedJob = await this.prisma.job.update({
      where: { id },
      data: {
        status: JobStatus.IN_PROGRESS,
        autoCompleteAt: null,
      },
      include: this.jobInclude,
    });

    // Notify Freelancer
    await this.notificationsService.sendNotification({
      userId: job.freelancerId,
      title: 'Revision Requested',
      body: `Client requested revision for Job #${job.id}: ${dto.reason}`,
      data: { type: 'job_revision', jobId: job.id.toString() },
    });

    // System Message
    await this.chatsService.postMessage(id, userId, role, {
      content: `[SYSTEM] Revision requested: ${dto.reason}`,
      type: 'system',
    });

    return this.withFlatFields(updatedJob);
  }

  async rejectJob(id: number, userId: number, role: UserRole) {
    this.ensureRole(role, [UserRole.FREELANCER]);
    const job = await this.ensureJobForFreelancer(id, userId);
    this.ensureValidTransition(job.status, JobStatus.REJECTED);

    // Notify Client
    await this.notificationsService.sendNotification({
      userId: job.clientId,
      title: 'Order Rejected',
      body: `Freelancer declined your order #${job.id}`,
      data: { type: 'job_rejected', jobId: job.id.toString() },
    });

    return this.applyStatusUpdate(id, JobStatus.REJECTED);
  }

  async cancelJob(id: number, userId: number, role: UserRole) {
    this.ensureRole(role, [UserRole.CLIENT]);
    const job = await this.ensureJobForClient(id, userId);
    this.ensureValidTransition(job.status, JobStatus.CANCELLED);
    return this.applyStatusUpdate(id, JobStatus.CANCELLED);
  }

  // Deprecated direct complete by Freelancer (now goes through Submit -> Review)
  // Kept for backward compat or forced completion if needed, 
  // but standard flow should be submitJob
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

  @Cron(CronExpression.EVERY_HOUR)
  async handleAutoCompleteJobs() {
    this.logger.log('Checking for auto-completable jobs...');
    const now = new Date();

    const jobs = await this.prisma.job.findMany({
      where: {
        status: JobStatus.IN_REVIEW,
        autoCompleteAt: { lte: now },
      },
    });

    for (const job of jobs) {
      try {
        this.logger.log(`Auto-completing job ${job.id}`);
        await this.applyStatusUpdate(job.id, JobStatus.COMPLETED);

        // Notify both parties
        await this.notificationsService.sendNotification({
          userId: job.freelancerId,
          title: 'Job Auto-Completed',
          body: `Job #${job.id} has been auto-completed due to 48h inactivity.`,
          data: { type: 'job_autocompleted', jobId: job.id.toString() },
        });

        await this.notificationsService.sendNotification({
          userId: job.clientId,
          title: 'Job Auto-Completed',
          body: `Job #${job.id} has been auto-completed due to inactivity.`,
          data: { type: 'job_autocompleted', jobId: job.id.toString() },
        });

      } catch (error) {
        this.logger.error(`Failed to auto-complete job ${job.id}`, error);
      }
    }
  }

  private ensureValidTransition(current: JobStatus, next: JobStatus) {
    const transitions: Record<JobStatus, JobStatus[]> = {
      [JobStatus.PENDING]: [
        JobStatus.ACCEPTED,
        JobStatus.IN_PROGRESS, // Direct start
        JobStatus.REJECTED,
        JobStatus.CANCELLED,
      ],
      [JobStatus.ACCEPTED]: [JobStatus.IN_PROGRESS, JobStatus.CANCELLED],
      [JobStatus.IN_PROGRESS]: [
        JobStatus.IN_REVIEW,
        JobStatus.COMPLETED, // Legacy/Manual fallback
        JobStatus.CANCELLED,
        JobStatus.DISPUTED,
      ],
      [JobStatus.IN_REVIEW]: [
        JobStatus.COMPLETED,
        JobStatus.IN_PROGRESS, // Revision
        JobStatus.DISPUTED,
      ],
      [JobStatus.COMPLETED]: [JobStatus.DISPUTED],
      [JobStatus.CANCELLED]: [],
      [JobStatus.REJECTED]: [JobStatus.CANCELLED],
      [JobStatus.DISPUTED]: [],
    };

    const allowedNextStates = transitions[current] ?? [];
    if (!allowedNextStates.includes(next)) {
      throw new ConflictException(`Invalid status transition from ${current} to ${next}`);
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

      // Validate escrow allows transition BEFORE updating job
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
          autoCompleteAt: status === JobStatus.COMPLETED ? null : undefined, // clear if completed
        },
        include: this.jobInclude,
      });

      // Sync escrow status
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
        select: { id: true, title: true, thumbnailUrl: true },
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
      service?: { id: number; title: string; thumbnailUrl?: string | null } | null;
      client?: { id: number; name: string } | null;
      freelancer?: { id: number; name: string } | null;
      clientId?: number;
      freelancerId?: number;
    },
  >(job: T) {
    return {
      ...job,
      serviceTitle: job.service?.title ?? null,
      serviceThumbnailUrl: job.service?.thumbnailUrl ?? null,
      clientId: job.client?.id ?? job.clientId ?? null,
      freelancerId: job.freelancer?.id ?? job.freelancerId ?? null,
    };
  }
}
