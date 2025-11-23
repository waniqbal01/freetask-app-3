import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { JobStatus, Prisma } from '@prisma/client';

@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: number, dto: CreateReviewDto) {
    const job = await this.prisma.job.findUnique({
      where: { id: dto.jobId },
      include: { review: true },
    });
    if (!job) {
      throw new NotFoundException('Job not found');
    }
    if (job.clientId !== userId) {
      throw new ForbiddenException('Only the client can review this job');
    }
    if (job.status !== JobStatus.COMPLETED) {
      throw new ForbiddenException('Job must be completed before reviewing');
    }
    if (job.review) {
      throw new ForbiddenException('Review already submitted');
    }

    const review = await this.prisma.review.create({
      data: {
        jobId: job.id,
        reviewerId: job.clientId,
        revieweeId: job.freelancerId,
        rating: dto.rating,
        comment: dto.comment,
      },
    });

    return review;
  }

  findMany(filters: { jobId?: number; serviceId?: number; freelancerId?: number }) {
    const where: Prisma.ReviewWhereInput = {};

    if (filters.jobId) {
      where.jobId = filters.jobId;
    }

    if (filters.serviceId) {
      where.job = {
        ...(where.job as Prisma.JobWhereInput | undefined),
        serviceId: filters.serviceId,
      };
    }

    if (filters.freelancerId) {
      where.revieweeId = filters.freelancerId;
    }

    return this.prisma.review.findMany({
      where,
      include: {
        job: {
          include: { service: true, client: true, freelancer: true },
        },
        reviewer: { select: { id: true, name: true } },
        reviewee: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findMine(userId: number) {
    return this.prisma.review.findMany({
      where: { revieweeId: userId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
