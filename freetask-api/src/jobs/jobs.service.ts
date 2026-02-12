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
import { CreateInquiryDto } from './dto/create-inquiry.dto';
import { DisputeJobDto } from './dto/dispute-job.dto';
import { UpdateJobStatusDto } from './dto/update-job-status.dto';
import { SubmitJobDto } from './dto/submit-job.dto';
import { RequestRevisionDto } from './dto/request-revision.dto';
import { JOB_MIN_DISPUTE_REASON_LEN } from './constants';
import { EscrowService } from '../escrow/escrow.service';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { ChatsService } from '../chats/chats.service';

@Injectable()
export class JobsService {
  private readonly logger = new Logger(JobsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly escrowService: EscrowService,
    private readonly notificationsService: NotificationsService,
    private readonly chatsService: ChatsService,
    // Inject PaymentsService (Optional to avoid circular if needed, but safe here per check)
    // Actually, creating a circular ref: JobsModule imports PaymentsModule?
    // Let's use ModuleRef or forwardRef if needed. If PaymentsService uses JobsService? No, PaymentsService uses Prisma directly. Safe.
    private readonly paymentsService: PaymentsService,
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

    // NOTE: Escrow is NOT created here anymore
    // It will be created when payment is completed (AWAITING_PAYMENT → IN_PROGRESS)

    // Notify Freelancer
    await this.notificationsService.sendNotification({
      userId: service.freelancerId,
      title: 'New Order Received',
      body: `You have received a new order: ${trimmedTitle}. Please review and accept/reject.`,
      data: { type: 'job_order', jobId: job.id.toString() },
    });

    return this.withFlatFields(job);
  }

  async createInquiry(userId: number, role: UserRole, dto: CreateInquiryDto) {
    if (role !== UserRole.CLIENT) {
      throw new ForbiddenException('Only clients can create inquiries');
    }

    const service = await this.prisma.service.findUnique({
      where: { id: dto.serviceId },
    });
    if (!service) {
      throw new NotFoundException('Service not found');
    }

    const job = await this.prisma.job.create({
      data: {
        title: service.title,
        description: dto.message,
        amount: new Prisma.Decimal(0),
        status: JobStatus.INQUIRY,
        serviceId: service.id,
        clientId: userId,
        freelancerId: service.freelancerId,
      },
      include: this.jobInclude,
    });

    await this.notificationsService.sendNotification({
      userId: service.freelancerId,
      title: 'New Inquiry',
      body: `New inquiry: ${dto.message.substring(0, 50)}...`,
      data: { type: 'job_inquiry', jobId: job.id.toString() },
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
    this.ensureValidTransition(job.status, JobStatus.AWAITING_PAYMENT);

    // Notify Client - Payment Required
    await this.notificationsService.sendNotification({
      userId: job.clientId,
      title: 'Order Accepted - Payment Required',
      body: `Freelancer has accepted your order #${job.id}. Please complete payment to proceed.`,
      data: { type: 'payment_required', jobId: job.id.toString() },
    });

    return this.applyStatusUpdate(id, JobStatus.AWAITING_PAYMENT);
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

  // Helper to touch startedAt
  private async setJobStarted(id: number) {
    await this.prisma.job.update({
      where: { id },
      data: { startedAt: new Date() }
    });
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

    // Check Minimum Duration Rule (e.g. 30 minutes)
    const MIN_DURATION_MS = 30 * 60 * 1000; // 30 mins
    let statusToSet: JobStatus = JobStatus.COMPLETED;
    let holdReason: string | null = null;

    if (job.startedAt) {
      const duration = Date.now() - job.startedAt.getTime();
      this.logger.log(`Job #${id} duration: ${duration}ms (Min: ${MIN_DURATION_MS}ms)`);

      if (duration < MIN_DURATION_MS) {
        statusToSet = JobStatus.PAYOUT_HOLD;
        holdReason = `Job completed too fast (${Math.floor(duration / 60000)} mins). Manual review required.`;
        this.logger.warn(`Job #${id} flagged for PAYOUT_HOLD: ${holdReason}`);
      }
    } else {
      // If startedAt is missing (legacy?), maybe fallback to createdAt or just allow?
      // Let's being strict? Or safe. Safe = Allow but log.
      this.logger.warn(`Job #${id} has no startedAt. Skipping duration check.`);
    }

    const updatedJob = await this.applyStatusUpdate(id, statusToSet, undefined, holdReason ?? undefined);

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
    this.ensureValidTransition(job.status, JobStatus.CANCELED);

    // Notify Client
    await this.notificationsService.sendNotification({
      userId: job.clientId,
      title: 'Order Rejected',
      body: `Freelancer declined your order #${job.id}`,
      data: { type: 'job_rejected', jobId: job.id.toString() },
    });

    return this.applyStatusUpdate(id, JobStatus.CANCELED);
  }

  async cancelJob(id: number, userId: number, role: UserRole) {
    this.ensureRole(role, [UserRole.CLIENT]);
    const job = await this.ensureJobForClient(id, userId);
    this.ensureValidTransition(job.status, JobStatus.CANCELED);
    return this.applyStatusUpdate(id, JobStatus.CANCELED);
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

    if (dto.status === JobStatus.CANCELED) {
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
      [JobStatus.INQUIRY]: [
        JobStatus.PENDING,          // Converted to Job
        JobStatus.CANCELED,         // Abandoned
      ],
      [JobStatus.PENDING]: [
        JobStatus.AWAITING_PAYMENT, // Freelancer accept
        JobStatus.CANCELED,          // Freelancer reject
        JobStatus.CANCELED,         // Client cancel
      ],
      [JobStatus.AWAITING_PAYMENT]: [
        JobStatus.IN_PROGRESS,       // Payment completed
        JobStatus.CANCELED,         // Client cancel before payment
      ],
      [JobStatus.IN_PROGRESS]: [
        JobStatus.IN_REVIEW,         // Freelancer submit work
        JobStatus.COMPLETED,         // Legacy/Manual fallback
        JobStatus.CANCELED,
        JobStatus.DISPUTED,
      ],
      [JobStatus.IN_REVIEW]: [
        JobStatus.COMPLETED,         // Client accept
        JobStatus.IN_PROGRESS,       // Revision
        JobStatus.DISPUTED,
      ],
      [JobStatus.COMPLETED]: [JobStatus.DISPUTED, JobStatus.PAYOUT_PROCESSING, JobStatus.PAYOUT_HOLD],
      [JobStatus.CANCELED]: [],
      [JobStatus.DISPUTED]: [JobStatus.COMPLETED, JobStatus.CANCELED],
      [JobStatus.SUBMITTED]: [JobStatus.COMPLETED, JobStatus.IN_PROGRESS, JobStatus.DISPUTED], // Added missing SUBMITTED status
      [JobStatus.PAYOUT_PROCESSING]: [JobStatus.PAID_OUT, JobStatus.PAYOUT_FAILED],
      [JobStatus.PAID_OUT]: [],
      [JobStatus.PAYOUT_FAILED]: [JobStatus.PAYOUT_PROCESSING, JobStatus.PAYOUT_FAILED_MANUAL],
      [JobStatus.PAYOUT_HOLD]: [JobStatus.COMPLETED, JobStatus.PAYOUT_FAILED_MANUAL],
      [JobStatus.PAYOUT_FAILED_MANUAL]: [JobStatus.PAYOUT_PROCESSING], // Allow retry?
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

  private async applyStatusUpdate(id: number, status: JobStatus, disputeReason?: string, holdReason?: string) {
    const result = await this.prisma.$transaction(async (tx) => {
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
          payoutHoldReason: holdReason ?? null,
          startedAt: status === JobStatus.IN_PROGRESS && !existingJob.startedAt ? new Date() : undefined, // Set startedAt if moving to IN_PROGRESS
          autoCompleteAt: status === JobStatus.COMPLETED ? null : undefined, // clear if completed
        },
        include: this.jobInclude,
      });

      // Credit Pending Balance & Calculate Fees on Completion
      // NOTE: If status is PAYOUT_HOLD, we treat it similarly to COMPLETED for calculation, 
      // but we do NOT release Escrow yet (Hold Escrow?).
      // Logic: If PAYOUT_HOLD, Job is "Done" effectively, but payment is stuck.
      // Escrow should be HELD -> RELEASED? No. Payout Logic will check status.
      // Ops... ensureValidTransition needs to know about PAYOUT_HOLD.

      if (status === JobStatus.COMPLETED && existingJob.status !== JobStatus.COMPLETED) {
        const amount = new Prisma.Decimal(existingJob.amount);
        const freelancerShare = amount.mul(0.9);
        const platformShare = amount.mul(0.1);

        // Update Job with calculated splits for Audit
        await tx.job.update({
          where: { id },
          data: {
            freelancerPayoutAmount: freelancerShare,
            platformFeeAmount: platformShare
          }
        });

        // Update User Pending Balance (Always done, as Weekly payout uses this as "Available")
        // NOTE: For IMMEDIATE mode, we might deduct it immediately after payout success in PaymentsService,
        // but adding it here keeps the ledger consistent: "Money became available".
        await tx.user.update({
          where: { id: existingJob.freelancerId },
          data: {
            pendingBalance: { increment: freelancerShare },
          },
        });

        // Trigger Immediate Payout if Configured
        // Check for PAYOUT_HOLD too? No, usually not triggered if held.
        // Needs to be done AFTER the transaction commits ideally, but inside is also ok if we accept async side effect logic outside tx.
        // ACTUALLY: We cannot await the payout inside this transaction because the JOB update needs to be committed for the Payout Service to see the 'COMPLETED' status (unless we pass the tx, but PaymentsService uses its own prisma calls).
        // Strategy: Return a flag or trigger it after this transaction block in the caller?
        // Or just let it run async without awaiting (fire and forget).
      }

      // Sync escrow status
      if (escrow) {
        await this.escrowService.syncOnJobStatus(tx, job, escrow);
      }

      return this.withFlatFields(job);
    });

    // Post-Transaction Actions
    if (status === JobStatus.COMPLETED) {
      // Fire and forget immediate payout logic
      this.paymentsService.processJobPayout(id).catch(err =>
        this.logger.error(`Immediate payout trigger failed for Job ${id}`, err)
      );
    }

    return result;
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
