import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { EscrowService } from '../escrow/escrow.service';
import { BillplzService } from './billplz.service';
import { CreatePaymentDto, VerifyPaymentDto } from './dto/payment.dto';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private prisma: PrismaService,
    private billplzService: BillplzService,
    private escrowService: EscrowService,
    private notificationsService: NotificationsService,
  ) { }

  async createPayment(dto: CreatePaymentDto) {
    // Check if job exists
    const job = await this.prisma.job.findUnique({
      where: { id: dto.jobId },
      include: {
        client: true,
        service: true,
      },
    });

    if (!job) {
      throw new NotFoundException('Job not found');
    }

    // NEW VALIDATION: Job must be in AWAITING_PAYMENT or PENDING status (legacy)
    if (job.status !== 'AWAITING_PAYMENT' && job.status !== 'PENDING') {
      throw new BadRequestException(
        `Payment can only be made for jobs in AWAITING_PAYMENT or PENDING status. Current status: ${job.status}`,
      );
    }

    // Check if payment already exists
    const existing = await this.prisma.payment.findUnique({
      where: { jobId: dto.jobId },
    });

    if (existing && existing.status === 'COMPLETED') {
      throw new BadRequestException('Payment already completed for this job');
    }

    // Calculate amount in cents (MYR)
    this.logger.debug(`Job amount (Decimal): ${job.amount}`);
    const amountInCents = Math.round(Number(job.amount) * 100);
    this.logger.log(
      `Preparing Billplz for Job #${job.id}, Amount: ${amountInCents} cents`,
    );

    if (isNaN(amountInCents)) {
      throw new BadRequestException(`Invalid job amount: ${job.amount}`);
    }

    // Call Billplz API
    const billplzResponse = await this.billplzService.createCollection(
      `Payment for Job #${job.id}: ${job.title}`,
      amountInCents,
      job.client.email,
      job.client.name,
      `Payment for service: ${job.service?.title ?? 'Custom Service'}`,
      `${process.env.API_URL || 'http://localhost:3000'}/payments/webhook`, // Server-to-server Webhook
      `${process.env.API_URL || 'http://localhost:3000'}/payments/callback`, // User Redirect (Backend -> Frontend)
    );

    // Create or Update payment record
    // If pending payment exists, we might want to update it or create new one.
    // For simplicity, let's assume one payment record per job.
    let payment;
    if (existing) {
      payment = await this.prisma.payment.update({
        where: { id: existing.id },
        data: {
          paymentGateway: 'billplz',
          transactionId: billplzResponse.id, // Save Billplz Bill ID
          status: 'PENDING',
        },
      });
    } else {
      payment = await this.prisma.payment.create({
        data: {
          jobId: dto.jobId,
          amount: job.amount,
          paymentMethod: dto.paymentMethod,
          paymentGateway: 'billplz',
          transactionId: billplzResponse.id,
          status: 'PENDING',
        },
      });
    }

    this.logger.log(
      `Created Billplz bill ${billplzResponse.id} for job ${dto.jobId}`,
    );

    return {
      payment,
      url: billplzResponse.url, // Return Billplz payment page URL
    };
  }

  async verifyPayment(dto: VerifyPaymentDto) {
    // This might be used for manual verification or checking status
    // Implementation depends on need. For now, webhook handles completion.
    const payment = await this.prisma.payment.findUnique({
      where: { jobId: dto.jobId },
    });

    if (!payment) {
      throw new NotFoundException('Payment not found');
    }

    return payment;
  }

  async getPaymentByJobId(jobId: number) {
    const payment = await this.prisma.payment.findUnique({
      where: { jobId },
      include: {
        job: {
          include: {
            service: true,
            client: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
            freelancer: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
          },
        },
      },
    });

    if (!payment) {
      throw new NotFoundException('Payment not found');
    }

    return payment;
  }

  async refundPayment(jobId: number) {
    // Logic for refunding payment (maybe call EscrowService.refund)
    // This is triggered by Admin usually.
    // TODO: Implement actual reversal via Billplz if API supported, otherwise just update record.
    const payment = await this.prisma.payment.findUnique({
      where: { jobId },
    });

    if (!payment || payment.status !== 'COMPLETED') {
      throw new BadRequestException('Cannot refund incomplete payment');
    }

    // This logic should align with EscrowService.refund
    // Currently EscrowService.refund handles the wallet refund.
    // We just update payment status here for record.

    const updated = await this.prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: 'FAILED', // Mark as FAILED since REFUNDED doesn't exist in PaymentStatus enum
      },
    });

    return updated;
  }

  async handleWebhook(payload: any, signature: string) {
    // Verify X-Signature
    const isValid = this.billplzService.verifyXSignature(payload, signature);
    if (!isValid) {
      this.logger.error('Invalid Billplz X-Signature');
      return { status: 'failed', message: 'Invalid signature' };
    }

    const billId = payload.id;
    const state = payload.state; // 'paid', 'due', 'deleted'

    this.logger.log(`Received webhook for bill ${billId}, state: ${state}`);

    const payment = await this.prisma.payment.findUnique({
      where: { transactionId: billId },
    });

    if (!payment) {
      this.logger.warn(`Payment not found for bill ${billId}`);
      return { status: 'failed', message: 'Payment not found' };
    }

    if (payment.status === 'COMPLETED') {
      this.logger.log(`Payment ${payment.id} already completed`);
      return { status: 'success' };
    }

    // Handle different payment states
    if (state === 'paid') {
      await this.markPaymentAsCompleted(payment);
    } else if (state === 'deleted') {
      // Payment cancelled/deleted by user
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: 'FAILED',
        },
      });
      this.logger.log(`Payment ${payment.id} cancelled by user`);

      // Notify client about failed payment
      const job = await this.prisma.job.findUnique({
        where: { id: payment.jobId },
        include: { client: true },
      });

      if (job) {
        await this.notificationsService.sendNotification({
          userId: job.clientId,
          title: 'Payment Failed',
          body: `Payment for job "${job.title}" was cancelled. Please retry payment to proceed.`,
          type: 'payment',
          data: {
            jobId: payment.jobId,
            paymentId: payment.id,
            status: 'failed',
          },
        });
      }
    } else if (state === 'due') {
      // Payment still pending/unpaid
      this.logger.log(`Payment ${payment.id} still due`);
    }

    return { status: 'success' };
  }

  async checkAndCompletePayment(billId: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { transactionId: billId },
    });

    if (!payment) {
      return null;
    }

    if (payment.status === 'COMPLETED') {
      return payment;
    }

    // Verify with Billplz API
    const bill = await this.billplzService.getBill(billId);

    if (bill && bill.state === 'paid') {
      this.logger.log(
        `Job Payment ${billId} verified as PAID via API check. Completing payment...`,
      );
      await this.markPaymentAsCompleted(payment);
      // Refresh payment
      return this.prisma.payment.findUnique({ where: { id: payment.id } });
    }

    return payment;
  }

  private async markPaymentAsCompleted(payment: any) {
    this.logger.log(
      `Completing payment ${payment.id} for Job ${payment.jobId}`,
    );

    // Payment successful - Use transaction to update payment, job status, and create escrow
    await this.prisma.$transaction(async (tx) => {
      // 1. Update payment status
      await tx.payment.update({
        where: { id: payment.id },
        data: {
          status: 'COMPLETED',
          paymentMethod: 'billplz',
        },
      });

      // 2. Update job status: AWAITING_PAYMENT → IN_PROGRESS
      await tx.job.update({
        where: { id: payment.jobId },
        data: {
          status: 'IN_PROGRESS',
        },
      });

      // 3. Create and hold escrow
      await tx.escrow.upsert({
        where: { jobId: payment.jobId },
        create: {
          jobId: payment.jobId,
          amount: payment.amount,
          status: 'HELD',
        },
        update: {
          status: 'HELD',
          amount: payment.amount,
        },
      });

      this.logger.log(
        `Payment completed, job ${payment.jobId} moved to IN_PROGRESS, escrow held`,
      );
    });

    // Send notifications after successful transaction
    const job = await this.prisma.job.findUnique({
      where: { id: payment.jobId },
      include: { client: true, freelancer: true },
    });

    if (job) {
      // Notify client
      await this.notificationsService.sendNotification({
        userId: job.clientId,
        title: 'Payment Successful - Work Starting',
        body: `Your payment of RM${payment.amount} for job "${job.title}" is completed. Freelancer can now start work.`,
        type: 'payment',
        data: {
          jobId: payment.jobId,
          paymentId: payment.id,
          status: 'success',
        },
      });

      // Notify freelancer
      await this.notificationsService.sendNotification({
        userId: job.freelancerId,
        title: 'Payment Received - You Can Start',
        body: `Payment of RM${payment.amount} received for "${job.title}". Funds are secured in escrow. You can now start work!`,
        type: 'payment',
        data: {
          jobId: payment.jobId,
          paymentId: payment.id,
          status: 'received',
        },
      });
    }
  }

  async getPaymentByTransactionId(transactionId: string) {
    return this.prisma.payment.findUnique({
      where: { transactionId },
      include: {
        job: {
          include: {
            service: true,
            client: true,
          },
        },
      },
    });
  }

  async retryPayment(jobId: number) {
    const existingPayment = await this.prisma.payment.findUnique({
      where: { jobId },
      include: {
        job: {
          include: {
            client: true,
            service: true,
          },
        },
      },
    });

    if (!existingPayment) {
      throw new NotFoundException('Payment not found');
    }

    if (existingPayment.status === 'COMPLETED') {
      throw new BadRequestException('Payment already completed');
    }

    const job = existingPayment.job;
    const amountInCents = Math.round(Number(job.amount) * 100);

    // Create new bill in Billplz
    const billplzResponse = await this.billplzService.createCollection(
      `Payment Retry for Job #${job.id}: ${job.title}`,
      amountInCents,
      job.client.email,
      job.client.name,
      `Payment for service: ${job.service?.title ?? 'Custom Service'}`,
      `${process.env.API_URL || 'http://localhost:3000'}/payments/webhook`, // Server-to-server Webhook
      `${process.env.API_URL || 'http://localhost:3000'}/payments/callback`, // User Redirect (Backend -> Frontend)
    );

    // ... existing code ...

    // Update payment with new transaction ID
    const updatedPayment = await this.prisma.payment.update({
      where: { id: existingPayment.id },
      data: {
        transactionId: billplzResponse.id,
        status: 'PENDING',
      },
    });

    this.logger.log(
      `Payment retry created for job ${jobId}, new bill: ${billplzResponse.id}`,
    );

    return {
      payment: updatedPayment,
      url: billplzResponse.url,
    };
  }

  async getPaymentHistory(userId: number) {
    // Get all payments for jobs where user is the client
    return this.prisma.payment.findMany({
      where: {
        job: {
          clientId: userId,
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        job: {
          select: {
            id: true,
            title: true,
            status: true,
          },
        },
      },
    });
  }

  // Logic to payout a specific job immediately (Atomic & Safe)
  async processJobPayout(jobId: number) {
    this.logger.log(`Processing immediate payout for Job #${jobId}`);

    // 1. ATOMIC LOCK: Try to move job to PAYOUT_PROCESSING
    // We catch 'COMPLETED' or 'PAYOUT_FAILED' states.
    const updateResult = await this.prisma.job.updateMany({
      where: {
        id: jobId,
        status: { in: ['COMPLETED', 'PAYOUT_FAILED'] },
        freelancerPayoutAmount: { not: null }, // Ensure amount is calculated
      },
      data: {
        status: 'PAYOUT_PROCESSING',
      },
    });

    if (updateResult.count === 0) {
      this.logger.warn(
        `Skipping payout for Job #${jobId}: Invalid state or already processing.`,
      );
      return {
        status: 'skipped',
        message: 'Job not in valid state for payout',
      };
    }

    // Fetch job details (now locked)
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { freelancer: true },
    });

    if (!job || !job.freelancer.bankCode || !job.freelancer.bankAccount) {
      // Revert state if data missing (Critical error, maybe manual intervention needed)
      this.logger.error(
        `Missing bank details for Job #${jobId}. Moving to PAYOUT_FAILED.`,
      );
      await this.prisma.job.update({
        where: { id: jobId },
        data: { status: 'PAYOUT_FAILED' },
      });
      return { status: 'failed', message: 'Missing bank details' };
    }

    // TRUST SCORE CHECK
    const TRUST_THRESHOLD = 80; // Example threshold
    if (job.freelancer.trustScore < TRUST_THRESHOLD) {
      this.logger.warn(
        `Job #${jobId} payout held: Trust Score ${job.freelancer.trustScore} < ${TRUST_THRESHOLD}`,
      );
      await this.prisma.job.update({
        where: { id: jobId },
        data: {
          status: 'PAYOUT_HOLD',
          payoutHoldReason: `Trust Score ${job.freelancer.trustScore} < ${TRUST_THRESHOLD}`,
        },
      });
      return { status: 'held', message: 'Payout held due to low trust score' };
    }

    try {
      // 2. CALL BILLPLZ API
      const amountInCents = Math.round(
        Number(job.freelancerPayoutAmount) * 100,
      );
      const referenceId = `PAYOUT-J${job.id}-${Date.now()}`;

      const payoutResponse = await this.billplzService.createPayout(
        job.freelancer.bankCode,
        job.freelancer.bankAccount,
        amountInCents,
        job.freelancer.bankHolderName || job.freelancer.name,
        referenceId,
      );

      // 3. SUCCESS: UPDATE TO PAID_OUT & DECREMENT BALANCE & RECORD WITHDRAWAL
      await this.prisma.$transaction(async (tx) => {
        // Update Job
        await tx.job.update({
          where: { id: jobId },
          data: {
            status: 'PAID_OUT',
            billplzPayoutId: payoutResponse.id,
          },
        });

        // Decrement Pending Balance
        await tx.user.update({
          where: { id: job.freelancerId },
          data: {
            pendingBalance: { decrement: job.freelancerPayoutAmount ?? 0 },
          },
        });

        // Create Withdrawal Record
        await tx.withdrawal.create({
          data: {
            freelancerId: job.freelancerId,
            amount: job.freelancerPayoutAmount ?? 0,
            status: 'COMPLETED', // Changed from APPROVED which doesn't exist in WithdrawalStatus enum
            bankDetails: {
              bankCode: job.freelancer.bankCode,
              bankAccount: job.freelancer.bankAccount,
              bankHolder: job.freelancer.bankHolderName,
            },
            processedAt: new Date(),
            // processedById: SYSTEM_USER_ID ?
          },
        });
      });

      this.logger.log(`✅ Immediate payout success for Job #${jobId}`);

      // Notify Freelancer
      await this.notificationsService.sendNotification({
        userId: job.freelancerId,
        title: 'Payout Sent',
        body: `RM${job.freelancerPayoutAmount} for Job #${job.id} has been transferred to your bank.`,
        type: 'payout',
        data: { jobId: job.id.toString(), status: 'paid_out' },
      });

      return { status: 'success', payoutId: payoutResponse.id };
    } catch (error) {
      this.logger.error(`❌ Immediate payout failed for Job #${jobId}`, error);

      // 4. FAIL: UPDATE TO PAYOUT_FAILED (Do NOT revert to COMPLETED)
      await this.prisma.job.update({
        where: { id: jobId },
        data: { status: 'PAYOUT_FAILED' },
      });

      return { status: 'failed', message: error.message };
    }
  }

  // Recovery Cron for Stuck Payouts
  @Cron('*/30 * * * *')
  async processStuckPayouts() {
    this.logger.log('Running Stuck Payout Recovery...');

    const thirtyMinsAgo = new Date(Date.now() - 30 * 60 * 1000);

    const stuckJobs = await this.prisma.job.findMany({
      where: {
        status: 'PAYOUT_PROCESSING',
        updatedAt: { lt: thirtyMinsAgo },
      },
      include: { freelancer: true },
    });

    for (const job of stuckJobs) {
      // Check retry limit
      if (job.payoutRetryCount >= 3) {
        this.logger.error(
          `Job #${job.id} exceeded retry limit. Moving to PAYOUT_FAILED_MANUAL.`,
        );
        await this.prisma.job.update({
          where: { id: job.id },
          data: { status: 'PAYOUT_FAILED_MANUAL' },
        });
        continue;
      }

      // Trust Check (Don't retry if low trust - move to HOLD?)
      const TRUST_THRESHOLD = 80;
      if (job.freelancer.trustScore < TRUST_THRESHOLD) {
        await this.prisma.job.update({
          where: { id: job.id },
          data: {
            status: 'PAYOUT_HOLD',
            payoutHoldReason: 'Stuck payout & Low Trust - Manual Review',
          },
        });
        continue;
      }

      this.logger.log(
        `Retrying stuck payout for Job #${job.id} (Attempt ${job.payoutRetryCount + 1})`,
      );

      // Increment retry count
      await this.prisma.job.update({
        where: { id: job.id },
        data: { payoutRetryCount: { increment: 1 } },
      });

      // Trigger payout again
      // We await here because this is a maintenance cron, so serial execution is fine/safer.
      try {
        await this.processJobPayout(job.id);
      } catch (error) {
        this.logger.error(`Retry failed for Job #${job.id}`, error);
      }
    }
  }
}
