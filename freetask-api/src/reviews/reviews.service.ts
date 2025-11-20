import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { JobStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateReviewDto } from './dto/create-review.dto';

@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  async createReview(reviewerId: number, dto: CreateReviewDto) {
    const job = await this.prisma.job.findUnique({
      where: { id: dto.jobId },
      include: { review: true },
    });

    if (!job) {
      throw new NotFoundException('Job not found');
    }

    if (job.status !== JobStatus.COMPLETED) {
      throw new ForbiddenException('Reviews can only be created for completed jobs');
    }

    if (job.clientId !== reviewerId && job.freelancerId !== reviewerId) {
      throw new ForbiddenException('You are not a participant in this job');
    }

    if (job.review) {
      throw new BadRequestException('A review has already been submitted for this job');
    }

    if (dto.revieweeId !== job.clientId && dto.revieweeId !== job.freelancerId) {
      throw new BadRequestException('Reviewee must be part of the job');
    }

    return this.prisma.review.create({
      data: {
        rating: dto.rating,
        comment: dto.comment,
        jobId: job.id,
        reviewerId,
        revieweeId: dto.revieweeId,
      },
    });
  }

  getReviewsForService(serviceId: number) {
    return this.prisma.review.findMany({
      where: { job: { serviceId } },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        rating: true,
        comment: true,
        createdAt: true,
        job: {
          select: { id: true },
        },
        reviewer: {
          select: { id: true, name: true },
        },
      },
    });
  }

  getReviewsForUser(userId: number) {
    return this.prisma.review.findMany({
      where: { revieweeId: userId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        rating: true,
        comment: true,
        createdAt: true,
        jobId: true,
        reviewer: {
          select: { id: true, name: true },
        },
      },
    });
  }

  async getServiceRatingSummary(serviceId: number) {
    const aggregate = await this.prisma.review.aggregate({
      where: { job: { serviceId } },
      _avg: { rating: true },
      _count: { _all: true },
    });

    return {
      averageRating: aggregate._avg.rating ?? 0,
      reviewCount: aggregate._count._all,
    };
  }
}
