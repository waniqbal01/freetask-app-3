import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { JobStatus, Prisma, ReportStatus, UserRole } from '@prisma/client';
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

    const updated = await this.prisma.job.update({
      where: { id: jobId },
      data: {
        status,
        disputeReason: null,
      },
    });

    await this.prisma.jobHistory.create({
      data: {
        jobId: jobId,
        action: 'JOB_RESOLVED_ADMIN',
        message: `Status ditetapkan kepada ${status}`,
      },
    });

    return updated;
  }

  deactivateService(serviceId: number) {
    return this.prisma.service.update({
      where: { id: serviceId },
      data: { active: false },
      select: { id: true, title: true, active: true },
    });
  }

  disableUser(userId: number) {
    return this.prisma.user.update({
      where: { id: userId },
      data: { enabled: false },
      select: { id: true, email: true, enabled: true },
    });
  }

  async getOpenReports() {
    return this.prisma.report.findMany({
      where: { status: ReportStatus.OPEN },
      orderBy: { createdAt: 'desc' },
      include: {
        reporter: { select: { id: true, name: true, email: true } },
        reportedUser: { select: { id: true, name: true, email: true } },
        reportedService: { select: { id: true, title: true, category: true } },
      },
    });
  }

  updateReportStatus(id: number, status: ReportStatus) {
    if (!Object.values(ReportStatus).includes(status)) {
      throw new BadRequestException('Status report tidak sah');
    }

    return this.prisma.report.update({
      where: { id },
      data: { status },
    });
  }

  async get7DayMetrics() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const days = Array.from({ length: 7 }, (_, index) => {
      const date = new Date(today);
      date.setDate(today.getDate() - (6 - index));
      return date;
    });

    const metrics = await Promise.all(
      days.map(async (day) => {
        const nextDay = new Date(day);
        nextDay.setDate(day.getDate() + 1);

        const [jobs, services, users] = await Promise.all([
          this.prisma.job.count({
            where: { createdAt: { gte: day, lt: nextDay } },
          }),
          this.prisma.service.count({
            where: { createdAt: { gte: day, lt: nextDay } },
          }),
          this.prisma.user.count({
            where: { createdAt: { gte: day, lt: nextDay } },
          }),
        ]);

        return {
          date: day.toISOString().split('T')[0],
          jobs,
          services,
          users,
        };
      }),
    );

    return {
      jobsPerDay: metrics.map((item) => ({ date: item.date, count: item.jobs })),
      servicesPerDay: metrics.map((item) => ({ date: item.date, count: item.services })),
      usersPerDay: metrics.map((item) => ({ date: item.date, count: item.users })),
    };
  }
}
