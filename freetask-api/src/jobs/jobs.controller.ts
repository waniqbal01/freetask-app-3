import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
  Query,
} from '@nestjs/common';
import { JobsService } from './jobs.service';
import { CreateJobDto } from './dto/create-job.dto';
import { DisputeJobDto } from './dto/dispute-job.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { UserRole } from '@prisma/client';

@Controller('jobs')
@UseGuards(JwtAuthGuard)
export class JobsController {
  constructor(private readonly jobsService: JobsService) {}

  @Post()
  create(
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Body() dto: CreateJobDto,
  ) {
    return this.jobsService.create(userId, role, dto);
  }

  @Get()
  findAll(
    @GetUser('userId') userId: number,
    @Query('scope') scope?: 'client' | 'freelancer' | 'all',
  ) {
    return this.jobsService.findAllForUser(userId, scope);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.findOneForUser(id, userId);
  }

  @Patch(':id/accept')
  accept(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.acceptJob(id, userId);
  }

  @Patch(':id/start')
  start(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.startJob(id, userId);
  }

  @Patch(':id/reject')
  reject(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.rejectJob(id, userId);
  }

  @Patch(':id/complete')
  complete(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.completeJob(id, userId);
  }

  @Patch(':id/dispute')
  dispute(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @Body() dto: DisputeJobDto,
  ) {
    return this.jobsService.disputeJob(id, userId, dto);
  }
}
