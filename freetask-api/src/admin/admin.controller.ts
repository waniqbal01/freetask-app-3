import {
  Body,
  Controller,
  DefaultValuePipe,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JobStatus, UserRole } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { AdminService } from './admin.service';
import { ResolveDisputeDto } from './dto/resolve-dispute.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('overview')
  getOverview() {
    return this.adminService.getOverviewStats();
  }

  @Get('users')
  getUsers(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('pageSize', new DefaultValuePipe(20), ParseIntPipe) pageSize: number,
  ) {
    return this.adminService.getAllUsers(page, pageSize);
  }

  @Get('jobs')
  getJobs(@Query('filter') filter?: string) {
    const normalized = filter?.toLowerCase();
    const disputeOnly = normalized === 'dispute' || normalized === 'disputes';
    return this.adminService.getAllJobs(disputeOnly ? 'dispute' : 'all');
  }

  @Get('jobs/disputes')
  getDisputedJobs() {
    return this.adminService.getDisputedJobs();
  }

  @Patch('jobs/:id/resolve')
  resolveDispute(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: ResolveDisputeDto,
  ) {
    const status = body.status as JobStatus;
    return this.adminService.resolveDispute(id, status);
  }
}
