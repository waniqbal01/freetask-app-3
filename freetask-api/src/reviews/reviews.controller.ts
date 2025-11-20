import { Body, Controller, Get, Param, ParseIntPipe, Post, UseGuards } from '@nestjs/common';
import { ReviewsService } from './reviews.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { CreateReviewDto } from './dto/create-review.dto';

@UseGuards(JwtAuthGuard)
@Controller('reviews')
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Post()
  create(@GetUser('userId') userId: number, @Body() dto: CreateReviewDto) {
    return this.reviewsService.createReview(userId, dto);
  }

  @Get('service/:serviceId')
  getServiceReviews(@Param('serviceId', ParseIntPipe) serviceId: number) {
    return this.reviewsService.getReviewsForService(serviceId);
  }

  @Get('user/:userId')
  getUserReviews(@Param('userId', ParseIntPipe) userId: number) {
    return this.reviewsService.getReviewsForUser(userId);
  }
}
