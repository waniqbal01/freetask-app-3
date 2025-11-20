import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { JobStatus, Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async getOverviewStats() {
    const [
      totalUsers,
      totalClients,
      totalFreelancers,
      totalServices,
      totalJobs,
      jobsGrouped,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { role: UserRole.CLIENT } }),
      this.prisma.user.count({ where: { role: UserRole.FREELANCER } }),
      this.prisma.service.count(),
      this.prisma.job.count(),
      this.prisma.job.groupBy({
        by: ['status'],
        _count: { status: true },
      }),
    ]);

    const jobsByStatus = Object.fromEntries(
      jobsGrouped.map((group) => [group.status, group._count.status]),
    );

    return {
      totalUsers,
      totalClients,
      totalFreelancers,
      totalServices,
      totalJobs,
      totalCompletedJobs: jobsByStatus[JobStatus.COMPLETED] ?? 0,
      totalDisputedJobs: jobsByStatus[JobStatus.DISPUTED] ?? 0,
      jobsByStatus,
    };
  }

  async getAllUsers(page = 1, pageSize = 20) {
    const take = Math.min(Math.max(pageSize, 1), 50);
    const skip = (Math.max(page, 1) - 1) * take;

    return this.prisma.user.findMany({
      skip,
      take,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        createdAt: true,
      },
    });
  }

  async getAllJobs(filter?: 'all' | 'dispute') {
    const where: Prisma.JobWhereInput = {};
    if (filter === 'dispute') {
      where.status = JobStatus.DISPUTED;
    }

    const jobs = await this.prisma.job.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        client: { select: { name: true } },
        freelancer: { select: { name: true } },
      },
    });

    return jobs.map((job) => ({
      id: job.id,
      title: job.title,
      status: job.status,
      clientName: job.client?.name ?? 'Tidak diketahui',
      freelancerName: job.freelancer?.name ?? 'Tidak diketahui',
      createdAt: job.createdAt,
    }));
  }

  async getDisputedJobs() {
    return this.getAllJobs('dispute');
  }

  async resolveDispute(jobId: number, status: JobStatus) {
    if (![JobStatus.COMPLETED, JobStatus.CANCELLED].includes(status)) {
      throw new BadRequestException('Status penyelesaian tidak sah');
    }

    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) {
      throw new NotFoundException('Job tidak dijumpai');
    }
    if (job.status !== JobStatus.DISPUTED) {
      throw new BadRequestException('Job ini bukan dalam status dispute');
    }

    return this.prisma.job.update({
      where: { id: jobId },
      data: {
        status,
        disputeReason: null,
      },
    });
  }
}
