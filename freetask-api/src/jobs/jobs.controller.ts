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
import { UpdateJobStatusDto } from './dto/update-job-status.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { UserRole } from '@prisma/client';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { JobsQueryDto } from './dto/jobs-query.dto';

@Controller('jobs')
@UseGuards(JwtAuthGuard, RolesGuard)
export class JobsController {
  constructor(private readonly jobsService: JobsService) { }

  @Post()
  @Roles(UserRole.CLIENT)
  create(
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Body() dto: CreateJobDto,
  ) {
    return this.jobsService.create(userId, role, dto);
  }

  @Get()
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  findAll(
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Query() query?: JobsQueryDto,
  ) {
    return this.jobsService.findAllForUser(userId, role, query?.filter, {
      limit: query?.limit,
      offset: query?.offset,
    });
  }

  @Get(':id')
  findOne(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.jobsService.findOneForUser(id, userId, role);
  }

  @Patch(':id/status')
  @Roles(UserRole.FREELANCER)
  updateStatus(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Body() dto: UpdateJobStatusDto,
  ) {
    return this.jobsService.updateStatus(id, userId, role, dto);
  }

  @Patch(':id/accept')
  @Roles(UserRole.FREELANCER)
  accept(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.jobsService.acceptJob(id, userId, role);
  }

  @Patch(':id/start')
  @Roles(UserRole.FREELANCER)
  start(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.jobsService.startJob(id, userId, role);
  }

  @Patch(':id/reject')
  @Roles(UserRole.FREELANCER)
  reject(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.jobsService.rejectJob(id, userId, role);
  }

  @Patch(':id/cancel')
  @Roles(UserRole.CLIENT)
  cancel(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.jobsService.cancelJob(id, userId, role);
  }

  @Patch(':id/complete')
  @Roles(UserRole.FREELANCER)
  complete(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.jobsService.completeJob(id, userId, role);
  }

  @Patch(':id/dispute')
  @Roles(UserRole.FREELANCER, UserRole.CLIENT)
  dispute(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Body() dto: DisputeJobDto,
  ) {
    return this.jobsService.disputeJob(id, userId, role, dto);
  }
}
