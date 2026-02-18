import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ApprovalStatus, JobStatus, WithdrawalStatus } from '@prisma/client';

import { BillplzService } from '../payments/billplz.service';
import { PaymentsService } from '../payments/payments.service';
import {
  isValidBankCode,
  BILLPLZ_BANK_CODES,
} from '../payments/billplz.constants';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    private prisma: PrismaService,
    private billplzService: BillplzService,
    private paymentsService: PaymentsService,
  ) { }

  async getAnalytics() {
    const [
      totalUsers,
      totalJobs,
      totalServices,
      completedJobs,
      pendingJobs,
      disputedJobs,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.job.count(),
      this.prisma.service.count(),
      this.prisma.job.count({ where: { status: 'COMPLETED' } }),
      this.prisma.job.count({ where: { status: 'PENDING' } }),
      this.prisma.job.count({ where: { status: 'DISPUTED' } }),
    ]);

    const totalRevenue = await this.prisma.job.aggregate({
      where: { status: 'COMPLETED' },
      _sum: { amount: true },
    });

    return {
      totalUsers,
      totalJobs,
      totalServices,
      completedJobs,
      pendingJobs,
      disputedJobs,
      totalRevenue: totalRevenue._sum.amount || 0,
    };
  }

  async getUsers(limit = 50, offset = 0) {
    const users = await this.prisma.user.findMany({
      take: limit,
      skip: offset,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        createdAt: true,
        avatarUrl: true,
        isActive: true,
        trustScore: true,
        balance: true,
        _count: {
          select: {
            services: true,
            jobsAsClient: true,
            jobsAsFreelancer: true,
          },
        },
      },
    });

    const total = await this.prisma.user.count();

    return { users, total };
  }

  async updateUserStatus(userId: number, isActive: boolean, adminId: number) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { isActive },
    });

    await this.createAuditLog(
      adminId,
      isActive ? 'ACTIVATE_USER' : 'BAN_USER',
      'user',
      { userId, isActive },
    );

    return user;
  }

  async updateTrustScore(userId: number, score: number, adminId: number) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { trustScore: score },
    });

    await this.createAuditLog(adminId, 'UPDATE_TRUST_SCORE', 'user', {
      userId,
      score,
    });

    return user;
  }

  async getPendingServices(limit = 50, offset = 0) {
    const services = await this.prisma.service.findMany({
      where: { approvalStatus: ApprovalStatus.PENDING },
      take: limit,
      skip: offset,
      orderBy: { createdAt: 'desc' },
      include: {
        freelancer: {
          select: {
            id: true,
            name: true,
            email: true,
            avatarUrl: true,
          },
        },
      },
    });

    const total = await this.prisma.service.count({
      where: { approvalStatus: ApprovalStatus.PENDING },
    });

    return { services, total };
  }

  async approveService(serviceId: number, adminId: number) {
    const service = await this.prisma.service.update({
      where: { id: serviceId },
      data: {
        approvalStatus: ApprovalStatus.APPROVED,
        rejectionReason: null,
      },
    });

    await this.createAuditLog(adminId, 'APPROVE_SERVICE', 'service', {
      serviceId,
    });

    return service;
  }

  async rejectService(serviceId: number, reason: string, adminId: number) {
    const service = await this.prisma.service.update({
      where: { id: serviceId },
      data: {
        approvalStatus: ApprovalStatus.REJECTED,
        rejectionReason: reason,
      },
    });

    await this.createAuditLog(adminId, 'REJECT_SERVICE', 'service', {
      serviceId,
      reason,
    });

    return service;
  }

  async getAllOrders(limit = 50, offset = 0, status?: JobStatus) {
    const where = status ? { status } : {};

    const orders = await this.prisma.job.findMany({
      where,
      take: limit,
      skip: offset,
      orderBy: { createdAt: 'desc' },
      include: {
        service: {
          select: {
            id: true,
            title: true,
            thumbnailUrl: true,
          },
        },
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
        payment: true,
        escrow: true,
      },
    });

    const total = await this.prisma.job.count({ where });

    return { orders, total };
  }

  async getOrderDetails(orderId: number) {
    const order = await this.prisma.job.findUnique({
      where: { id: orderId },
      include: {
        service: true,
        client: {
          select: {
            id: true,
            name: true,
            email: true,
            avatarUrl: true,
          },
        },
        freelancer: {
          select: {
            id: true,
            name: true,
            email: true,
            avatarUrl: true,
          },
        },
        payment: true,
        escrow: true,
        reviews: true,
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    return order;
  }

  async getWithdrawals(limit = 50, offset = 0, status?: WithdrawalStatus) {
    const where = status ? { status } : {};

    const withdrawals = await this.prisma.withdrawal.findMany({
      where,
      take: limit,
      skip: offset,
      orderBy: { createdAt: 'desc' },
      include: {
        freelancer: {
          select: {
            id: true,
            name: true,
            email: true,
            balance: true,
          },
        },
        processedBy: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
    });

    const total = await this.prisma.withdrawal.count({ where });

    return { withdrawals, total };
  }

  async approveWithdrawal(withdrawalId: number, adminId: number) {
    const withdrawal = await this.prisma.withdrawal.findUnique({
      where: { id: withdrawalId },
      include: { freelancer: true },
    });

    if (!withdrawal) {
      throw new NotFoundException('Withdrawal not found');
    }

    if (
      withdrawal.status !== WithdrawalStatus.PENDING &&
      withdrawal.status !== WithdrawalStatus.REJECTED
    ) {
      throw new BadRequestException(
        'Withdrawal already processed or not eligible for retry',
      );
    }

    // 1. Retry Locking Logic
    if (withdrawal.lastAttemptAt) {
      const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
      if (withdrawal.lastAttemptAt > fiveMinutesAgo) {
        throw new BadRequestException(
          'Please wait 5 minutes before retrying this payout to avoid double processing.',
        );
      }
    }

    // 2. Bank Details Validation
    const bankDetails = withdrawal.bankDetails as any;
    if (!bankDetails || !bankDetails.bankCode || !bankDetails.accountNumber) {
      throw new BadRequestException('Invalid bank details structure.');
    }

    if (!isValidBankCode(bankDetails.bankCode)) {
      throw new BadRequestException(
        `Invalid bank code: ${bankDetails.bankCode}. Must be one of: ${BILLPLZ_BANK_CODES.join(', ')}`,
      );
    }

    if (!/^\d+$/.test(bankDetails.accountNumber)) {
      throw new BadRequestException('Account number must contain only digits.');
    }

    if (withdrawal.freelancer.balance < withdrawal.amount) {
      throw new BadRequestException('Insufficient balance');
    }

    // 3. Initiate Billplz Payout
    // Update lastAttemptAt first to lock it
    await this.prisma.withdrawal.update({
      where: { id: withdrawalId },
      data: { lastAttemptAt: new Date() },
    });

    let payoutResult;
    try {
      // Amount in cents
      const amountInCents = Math.round(Number(withdrawal.amount) * 100);

      payoutResult = await this.billplzService.createPayout(
        bankDetails.bankCode,
        bankDetails.accountNumber,
        amountInCents,
        bankDetails.bankHolderName || withdrawal.freelancer.name,
        `WD-${withdrawal.id}`, // Reference ID
      );

      this.logger.log(`Payout initiated: ${payoutResult.id}`);
    } catch (error) {
      this.logger.error(
        `Payout Failed for WD-${withdrawal.id}: ${error.message}`,
      );

      // On Failure: Update status to FAILED, Save Error (DO NOT DEDUCT BALANCE)
      await this.prisma.withdrawal.update({
        where: { id: withdrawalId },
        data: {
          status: WithdrawalStatus.REJECTED, // Changed from PAYOUT_FAILED which doesn't exist
          payoutError: error.message || 'Unknown Billplz Error',
        },
      });

      // Re-throw to inform Admin
      throw new BadRequestException(`Payout failed: ${error.message}`);
    }

    // 4. Handle Success -> Deduct Balance & Approve
    const result = await this.prisma.$transaction(async (tx) => {
      const updatedWithdrawal = await tx.withdrawal.update({
        where: { id: withdrawalId },
        data: {
          status: WithdrawalStatus.COMPLETED, // Changed from APPROVED which doesn't exist
          processedAt: new Date(),
          processedById: adminId,
          billplzPayoutId: payoutResult.id,
          payoutError: null, // Clear previous errors
        },
      });

      await tx.user.update({
        where: { id: withdrawal.freelancerId },
        data: {
          balance: {
            decrement: withdrawal.amount,
          },
        },
      });

      return updatedWithdrawal;
    });

    await this.createAuditLog(adminId, 'APPROVE_WITHDRAWAL', 'withdrawal', {
      withdrawalId,
      amount: withdrawal.amount,
      payoutId: payoutResult.id,
    });

    return result;
  }

  async rejectWithdrawal(
    withdrawalId: number,
    reason: string,
    adminId: number,
  ) {
    const withdrawal = await this.prisma.withdrawal.findUnique({
      where: { id: withdrawalId },
    });

    if (!withdrawal) {
      throw new NotFoundException('Withdrawal not found');
    }

    if (withdrawal.status !== WithdrawalStatus.PENDING) {
      throw new BadRequestException('Withdrawal already processed');
    }

    const result = await this.prisma.withdrawal.update({
      where: { id: withdrawalId },
      data: {
        status: WithdrawalStatus.REJECTED,
        rejectionReason: reason,
        processedAt: new Date(),
        processedById: adminId,
      },
    });

    await this.createAuditLog(adminId, 'REJECT_WITHDRAWAL', 'withdrawal', {
      withdrawalId,
      reason,
    });

    return result;
  }

  async getDisputes(limit = 50, offset = 0) {
    const disputes = await this.prisma.job.findMany({
      where: { status: JobStatus.DISPUTED },
      take: limit,
      skip: offset,
      orderBy: { updatedAt: 'desc' },
      include: {
        service: {
          select: {
            id: true,
            title: true,
            thumbnailUrl: true,
          },
        },
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
        escrow: true,
      },
    });

    const total = await this.prisma.job.count({
      where: { status: JobStatus.DISPUTED },
    });

    return { disputes, total };
  }

  async resolveDispute(
    jobId: number,
    resolution: 'RELEASE' | 'REFUND' | 'PARTIAL',
    adminId: number,
    refundAmount?: number,
    notes?: string,
  ) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { escrow: true },
    });

    if (!job) {
      throw new NotFoundException('Job not found');
    }

    if (job.status !== JobStatus.DISPUTED) {
      throw new BadRequestException('Job is not in disputed status');
    }

    // Update job status and escrow based on resolution
    const result = await this.prisma.$transaction(async (tx) => {
      let updatedJob;
      let escrowStatus;

      switch (resolution) {
        case 'RELEASE':
          updatedJob = await tx.job.update({
            where: { id: jobId },
            data: { status: JobStatus.COMPLETED },
          });
          if (job.escrow) {
            await tx.escrow.update({
              where: { id: job.escrow.id },
              data: { status: 'RELEASED' },
            });
          }
          // Add amount to freelancer balance
          await tx.user.update({
            where: { id: job.freelancerId },
            data: { balance: { increment: job.amount } },
          });
          break;

        case 'REFUND':
          updatedJob = await tx.job.update({
            where: { id: jobId },
            data: { status: JobStatus.CANCELED }, // Fixed typo: CANCELLED -> CANCELED
          });
          if (job.escrow) {
            await tx.escrow.update({
              where: { id: job.escrow.id },
              data: { status: 'REFUNDED' },
            });
          }
          break;

        case 'PARTIAL':
          if (!refundAmount) {
            throw new BadRequestException(
              'Refund amount required for partial resolution',
            );
          }
          updatedJob = await tx.job.update({
            where: { id: jobId },
            data: { status: JobStatus.COMPLETED },
          });
          // Calculate freelancer's share
          const freelancerShare = Number(job.amount) - refundAmount;
          if (freelancerShare > 0) {
            await tx.user.update({
              where: { id: job.freelancerId },
              data: { balance: { increment: freelancerShare } },
            });
          }
          if (job.escrow) {
            await tx.escrow.update({
              where: { id: job.escrow.id },
              data: { status: 'RELEASED' },
            });
          }
          break;
      }

      return updatedJob;
    });

    await this.createAuditLog(adminId, 'RESOLVE_DISPUTE', 'job', {
      jobId,
      resolution,
      refundAmount,
      notes,
    });

    return result;
  }

  async getAuditLogs(limit = 100, offset = 0) {
    const logs = await this.prisma.adminLog.findMany({
      take: limit,
      skip: offset,
      orderBy: { createdAt: 'desc' },
      include: {
        admin: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
    });

    const total = await this.prisma.adminLog.count();

    return { logs, total };
  }

  async createAuditLog(
    adminId: number,
    action: string,
    resource?: string,
    details?: any,
  ) {
    return this.prisma.adminLog.create({
      data: {
        adminId,
        action,
        resource,
        details,
      },
    });
  }

  async getSystemStats() {
    const now = new Date();
    const last30Days = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const [newUsersLast30Days, newJobsLast30Days, activeUsers] =
      await Promise.all([
        this.prisma.user.count({
          where: { createdAt: { gte: last30Days } },
        }),
        this.prisma.job.count({
          where: { createdAt: { gte: last30Days } },
        }),
        this.prisma.user.count({
          where: {
            OR: [
              { jobsAsClient: { some: { createdAt: { gte: last30Days } } } },
              {
                jobsAsFreelancer: { some: { createdAt: { gte: last30Days } } },
              },
            ],
          },
        }),
      ]);

    return {
      newUsersLast30Days,
      newJobsLast30Days,
      activeUsers,
    };
  }

  async releasePayoutHold(jobId: number, adminId: number) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { freelancer: true },
    });

    if (!job) {
      throw new NotFoundException('Job not found');
    }

    // Allow releasing hold or retrying failed payouts
    const allowedStatuses = [
      'PAYOUT_HOLD',
      'PAYOUT_FAILED',
      'PAYOUT_FAILED_MANUAL',
      'COMPLETED',
      'PAYOUT_PROCESSING',
    ];
    if (!allowedStatuses.includes(job.status)) {
      throw new BadRequestException(
        `Job status ${job.status} is not eligible for payout release`,
      );
    }

    // 1. Auto-Fix Trust Score if it's low
    if (job.freelancer.trustScore < 80) {
      this.logger.log(
        `Auto-fixing trust score for freelancer ${job.freelancerId} to allow payout`,
      );
      await this.prisma.user.update({
        where: { id: job.freelancerId },
        data: { trustScore: 100 },
      });
    }

    // 2. Force status to COMPLETED to allow processJobPayout to pick it up cleanly
    // processJobPayout expects COMPLETED or PAYOUT_FAILED.
    // If it's PAYOUT_HOLD, processJobPayout might not look for it specifically unless we change query there,
    // OR we just change status here to COMPLETED/PAYOUT_FAILED.
    // Let's set to PAYOUT_FAILED to be safe (as it's a retry state).
    await this.prisma.job.update({
      where: { id: jobId },
      data: {
        status: 'PAYOUT_FAILED', // Set to a state that processJobPayout accepts for retry
        payoutHoldReason: null, // Clear hold reason
      },
    });

    // 3. Trigger Payout
    const result = await this.paymentsService.processJobPayout(jobId);

    await this.createAuditLog(adminId, 'RELEASE_PAYOUT_HOLD', 'job', {
      jobId,
      originalStatus: job.status,
      result,
    });

    return result;
  }
  async markJobPaidManually(jobId: number, adminId: number, notes: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { freelancer: true },
    });

    if (!job) {
      throw new NotFoundException('Job not found');
    }

    // 1. Update Job Status
    const updatedJob = await this.prisma.job.update({
      where: { id: jobId },
      data: {
        status: 'PAID_OUT',
        payoutHoldReason: null,
        billplzPayoutId: `MANUAL-BY-ADMIN-${adminId}`,
      },
    });

    // 2. Adjust Balance (Move from Pending to "Withdrawn" effectively)
    // If money was in Pending Balance, we decrement it.
    if (
      job.freelancerPayoutAmount &&
      job.freelancerPayoutAmount.toNumber() > 0
    ) {
      await this.prisma.user.update({
        where: { id: job.freelancerId },
        data: {
          pendingBalance: { decrement: job.freelancerPayoutAmount },
        },
      });
    }

    // 3. Create Withdrawal Record for Audit
    await this.prisma.withdrawal.create({
      data: {
        freelancerId: job.freelancerId,
        amount: job.freelancerPayoutAmount ?? 0,
        status: 'COMPLETED', // Changed from APPROVED which doesn't exist in WithdrawalStatus enum
        bankDetails: {
          bankCode: job.freelancer.bankCode,
          bankAccount: job.freelancer.bankAccount,
          note: 'Marked as Paid Manually by Admin',
        },
        processedAt: new Date(),
        processedById: adminId,
        billplzPayoutId: 'MANUAL',
      },
    });

    await this.createAuditLog(adminId, 'MARK_JOB_PAID_MANUAL', 'job', {
      jobId,
      notes,
    });

    return updatedJob;
  }
}
