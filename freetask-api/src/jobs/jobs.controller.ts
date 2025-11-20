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
  UnauthorizedException,
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
  // CLIENT ONLY: Client creates a job/order from a selected service.
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
    @GetUser('userId') userId: number,
    @Query('filter') filter?: 'client' | 'freelancer' | 'all',
  ) {
    if (userId === null || userId === undefined) {
      throw new UnauthorizedException('User context is missing');
    }

    return this.jobsService.findAllForUser(userId, filter);
  }

  @ApiOperation({ summary: 'Get a job by ID if current user is involved' })
  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.findOneForUser(id, userId);
  }

  @ApiOperation({ summary: 'Get job activity history' })
  @Get(':id/history')
  getHistory(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.jobsService.getJobHistory(id, userId, role);
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
  // CLIENT ONLY: Confirm freelancer to proceed (PENDING -> ACCEPTED).
  @Patch(':id/accept')
  accept(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.jobsService.acceptJob(id, userId, role);
  }

  @ApiOperation({ summary: 'Freelancer starts work' })
  // FREELANCER ONLY: Start working on accepted job (ACCEPTED -> IN_PROGRESS).
  @Patch(':id/start')
  start(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.startJob(id, userId);
  }

  @ApiOperation({ summary: 'Reject a job' })
  // FREELANCER ONLY: Reject a pending job (PENDING -> REJECTED).
  @Patch(':id/reject')
  reject(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.rejectJob(id, userId);
  }

  @ApiOperation({ summary: 'Mark job completed by freelancer' })
  // CLIENT or FREELANCER: Mark as completed after work delivery (IN_PROGRESS -> COMPLETED).
  @Patch(':id/complete')
  complete(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.jobsService.completeJob(id, userId);
  }

  @ApiOperation({ summary: 'Raise a dispute with a reason' })
  // CLIENT or FREELANCER: Raise dispute with a reason (any active status -> DISPUTED).
  @Patch(':id/dispute')
  dispute(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @Body() dto: DisputeJobDto,
  ) {
    return this.jobsService.disputeJob(id, userId, dto);
  }
}
