import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ApprovalStatus, JobStatus, WithdrawalStatus } from '@prisma/client';

@Injectable()
export class AdminService {
    private readonly logger = new Logger(AdminService.name);

    constructor(private prisma: PrismaService) { }

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

        await this.createAuditLog(
            adminId,
            'APPROVE_SERVICE',
            'service',
            { serviceId },
        );

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

        await this.createAuditLog(
            adminId,
            'REJECT_SERVICE',
            'service',
            { serviceId, reason },
        );

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

        if (withdrawal.status !== WithdrawalStatus.PENDING) {
            throw new BadRequestException('Withdrawal already processed');
        }

        if (withdrawal.freelancer.balance < withdrawal.amount) {
            throw new BadRequestException('Insufficient balance');
        }

        // Update withdrawal status and user balance in a transaction
        const result = await this.prisma.$transaction(async (tx) => {
            const updatedWithdrawal = await tx.withdrawal.update({
                where: { id: withdrawalId },
                data: {
                    status: WithdrawalStatus.APPROVED,
                    processedAt: new Date(),
                    processedById: adminId,
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

        await this.createAuditLog(
            adminId,
            'APPROVE_WITHDRAWAL',
            'withdrawal',
            { withdrawalId, amount: withdrawal.amount },
        );

        return result;
    }

    async rejectWithdrawal(withdrawalId: number, reason: string, adminId: number) {
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

        await this.createAuditLog(
            adminId,
            'REJECT_WITHDRAWAL',
            'withdrawal',
            { withdrawalId, reason },
        );

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
                        data: { status: JobStatus.CANCELLED },
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
                        throw new BadRequestException('Refund amount required for partial resolution');
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

        await this.createAuditLog(
            adminId,
            'RESOLVE_DISPUTE',
            'job',
            { jobId, resolution, refundAmount, notes },
        );

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

    async createAuditLog(adminId: number, action: string, resource?: string, details?: any) {
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

        const [
            newUsersLast30Days,
            newJobsLast30Days,
            activeUsers,
        ] = await Promise.all([
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
                        { jobsAsFreelancer: { some: { createdAt: { gte: last30Days } } } },
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
}
