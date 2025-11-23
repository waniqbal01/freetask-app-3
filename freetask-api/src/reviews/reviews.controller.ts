import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ReviewsService } from './reviews.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { CreateReviewDto } from './dto/create-review.dto';

@Controller('reviews')
@UseGuards(JwtAuthGuard)
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Post()
  create(@GetUser('userId') userId: number, @Body() dto: CreateReviewDto) {
    return this.reviewsService.create(userId, dto);
  }

  @Get()
  findAll(
    @Query('jobId') jobId?: string,
    @Query('serviceId') serviceId?: string,
    @Query('freelancerId') freelancerId?: string,
  ) {
    const parsedJobId = jobId ? Number(jobId) : undefined;
    const parsedServiceId = serviceId ? Number(serviceId) : undefined;
    const parsedFreelancerId = freelancerId ? Number(freelancerId) : undefined;

    return this.reviewsService.findMany({
      jobId: Number.isFinite(parsedJobId) ? parsedJobId : undefined,
      serviceId: Number.isFinite(parsedServiceId) ? parsedServiceId : undefined,
      freelancerId: Number.isFinite(parsedFreelancerId) ? parsedFreelancerId : undefined,
    });
  }

  @Get('mine')
  findMine(@GetUser('userId') userId: number) {
    return this.reviewsService.findMine(userId);
  }
}
