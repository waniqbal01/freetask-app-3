import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

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
