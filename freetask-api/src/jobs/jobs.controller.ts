import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JobsService } from './jobs.service';
import { CreateJobDto } from './dto/create-job.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { GetUser } from '../common/decorators/get-user.decorator';
import { AuthUser } from '../auth/types/auth-user.type';

@Controller('jobs')
@UseGuards(JwtAuthGuard)
export class JobsController {
  constructor(private readonly jobsService: JobsService) {}

  @Post()
  create(@GetUser() user: AuthUser, @Body() dto: CreateJobDto) {
    return this.jobsService.create(user.id, user.role, dto);
  }

  @Get()
  findAll(@GetUser() user: AuthUser) {
    return this.jobsService.findAllForUser(user.id);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number, @GetUser() user: AuthUser) {
    return this.jobsService.findOneForUser(id, user.id);
  }

  @Patch(':id/accept')
  accept(@Param('id', ParseIntPipe) id: number, @GetUser() user: AuthUser) {
    return this.jobsService.acceptJob(id, user.id);
  }

  @Patch(':id/reject')
  reject(@Param('id', ParseIntPipe) id: number, @GetUser() user: AuthUser) {
    return this.jobsService.rejectJob(id, user.id);
  }

  @Patch(':id/complete')
  complete(@Param('id', ParseIntPipe) id: number, @GetUser() user: AuthUser) {
    return this.jobsService.completeJob(id, user.id);
  }

  @Patch(':id/dispute')
  dispute(@Param('id', ParseIntPipe) id: number, @GetUser() user: AuthUser) {
    return this.jobsService.disputeJob(id, user.id);
  }
}
