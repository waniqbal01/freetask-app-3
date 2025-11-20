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
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { JobsService } from './jobs.service';
import { CreateJobDto } from './dto/create-job.dto';
import { DisputeJobDto } from './dto/dispute-job.dto';
import { UpdateJobStatusDto } from './dto/update-job-status.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { UserRole } from '@prisma/client';

@ApiTags('Jobs')
@Controller('jobs')
@UseGuards(JwtAuthGuard)
export class JobsController {
  constructor(private readonly jobsService: JobsService) {}

  @ApiOperation({ summary: 'Create a new job from a service' })
  @Post()
  create(
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Body() dto: CreateJobDto,
  ) {
    return this.jobsService.create(userId, role, dto);
  }

  @ApiOperation({ summary: 'List jobs related to the current user' })
  @Get()
  findAll(
    @GetUser('id') userId: number,
    @Query('filter') filter?: 'client' | 'freelancer' | 'all',
  ) {
    return this.jobsService.findAllForUser(userId, filter);
  }

  @ApiOperation({ summary: 'Get a job by ID if current user is involved' })
  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.findOneForUser(id, userId);
  }

  @ApiOperation({ summary: 'Update job status explicitly' })
  @Patch(':id/status')
  updateStatus(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Body() dto: UpdateJobStatusDto,
  ) {
    return this.jobsService.updateStatus(id, userId, role, dto);
  }

  @ApiOperation({ summary: 'Client accepts a proposal' })
  @Patch(':id/accept')
  accept(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.acceptJob(id, userId);
  }

  @ApiOperation({ summary: 'Freelancer starts work' })
  @Patch(':id/start')
  start(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.startJob(id, userId);
  }

  @ApiOperation({ summary: 'Reject a job' })
  @Patch(':id/reject')
  reject(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.rejectJob(id, userId);
  }

  @ApiOperation({ summary: 'Mark job completed by freelancer' })
  @Patch(':id/complete')
  complete(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.completeJob(id, userId);
  }

  @ApiOperation({ summary: 'Raise a dispute with a reason' })
  @Patch(':id/dispute')
  dispute(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @Body() dto: DisputeJobDto,
  ) {
    return this.jobsService.disputeJob(id, userId, dto);
  }
}
