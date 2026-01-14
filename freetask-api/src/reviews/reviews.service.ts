import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { JobStatus, Prisma } from '@prisma/client';

@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) { }

  async create(userId: number, dto: CreateReviewDto) {
    const job = await this.prisma.job.findUnique({
      where: { id: dto.jobId },
      include: { reviews: true },
    });
    if (!job) {
      throw new NotFoundException('Job not found');
    }

    // Verify user is part of this job (client or freelancer)
    if (job.clientId !== userId && job.freelancerId !== userId) {
      throw new ForbiddenException('You are not part of this job');
    }

    if (job.status !== JobStatus.COMPLETED) {
      throw new ForbiddenException('Job must be completed before reviewing');
    }

    // Validate revieweeId is either client or freelancer of job
    if (dto.revieweeId !== job.clientId && dto.revieweeId !== job.freelancerId) {
      throw new ForbiddenException('Reviewee must be part of this job');
    }

    // Prevent self-reviews
    if (dto.revieweeId === userId) {
      throw new ForbiddenException('Cannot review yourself');
    }

    // Check for existing review with same (jobId, reviewerId, revieweeId)
    const existingReview = job.reviews.find(
      (r) => r.reviewerId === userId && r.revieweeId === dto.revieweeId
    );
    if (existingReview) {
      throw new ForbiddenException('You have already reviewed this person for this job');
    }

    const review = await this.prisma.review.create({
      data: {
        jobId: job.id,
        reviewerId: userId,
        revieweeId: dto.revieweeId,
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

  async findSubmitted(userId: number) {
    return this.prisma.review.findMany({
      where: { reviewerId: userId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
