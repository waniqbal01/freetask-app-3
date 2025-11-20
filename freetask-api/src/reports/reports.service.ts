import { BadRequestException, Injectable } from '@nestjs/common';
import { ReportStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateReportDto } from './dto/create-report.dto';

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async createReport(reporterId: number, dto: CreateReportDto) {
    if (!dto.reportedServiceId && !dto.reportedUserId) {
      throw new BadRequestException('Sila pilih pengguna atau servis untuk dilaporkan.');
    }

    return this.prisma.report.create({
      data: {
        reporterId,
        reportedUserId: dto.reportedUserId,
        reportedServiceId: dto.reportedServiceId,
        reason: dto.reason,
        status: ReportStatus.OPEN,
      },
    });
  }

  getOpenReports() {
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
      throw new BadRequestException('Status tidak sah');
    }

    return this.prisma.report.update({
      where: { id },
      data: { status },
    });
  }
}
