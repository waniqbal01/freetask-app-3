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
    @Query('serviceId') serviceId?: number,
    @Query('freelancerId') freelancerId?: number,
  ) {
    return this.reviewsService.findMany(
      serviceId ? Number(serviceId) : undefined,
      freelancerId ? Number(freelancerId) : undefined,
    );
  }

  @Get('mine')
  findMine(@GetUser('userId') userId: number) {
    return this.reviewsService.findMine(userId);
  }
}
