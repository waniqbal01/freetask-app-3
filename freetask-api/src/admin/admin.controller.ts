import {
  Controller,
  Get,
  Patch,
  Query,
  UseGuards,
  Request,
  Param,
  ParseIntPipe,
  Body,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminService } from './admin.service';
import { UpdateUserStatusDto } from './dto/update-user-status.dto';
import { RejectServiceDto } from './dto/reject-service.dto';
import { ResolveDisputeDto } from './dto/resolve-dispute.dto';
import { ProcessWithdrawalDto } from './dto/process-withdrawal.dto';
import { JobStatus, WithdrawalStatus } from '@prisma/client';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminController {
  constructor(private readonly adminService: AdminService) { }

  // Analytics
  @Get('analytics')
  async getAnalytics(@Request() req) {
    await this.adminService.createAuditLog(
      req.user.userId,
      'VIEW_ANALYTICS',
      'analytics',
    );
    return this.adminService.getAnalytics();
  }

  @Get('stats')
  async getSystemStats(@Request() req) {
    await this.adminService.createAuditLog(
      req.user.userId,
      'VIEW_STATS',
      'stats',
    );
    return this.adminService.getSystemStats();
  }

  // User Management
  @Get('users')
  async getUsers(
    @Request() req,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    const limitNum = limit ? parseInt(limit, 10) : 50;
    const offsetNum = offset ? parseInt(offset, 10) : 0;

    await this.adminService.createAuditLog(
      req.user.userId,
      'VIEW_USERS',
      'users',
    );

    return this.adminService.getUsers(limitNum, offsetNum);
  }

  @Patch('users/:id/status')
  async updateUserStatus(
    @Request() req,
    @Param('id', ParseIntPipe) userId: number,
    @Body() dto: UpdateUserStatusDto,
  ) {
    const isActive = dto.status === 'ACTIVE';
    return this.adminService.updateUserStatus(
      userId,
      isActive,
      req.user.userId,
    );
  }

  @Patch('users/:id/trust-score')
  async updateTrustScore(
    @Request() req,
    @Param('id', ParseIntPipe) userId: number,
    @Body('trustScore', ParseIntPipe) trustScore: number,
  ) {
    return this.adminService.updateTrustScore(
      userId,
      trustScore,
      req.user.userId,
    );
  }

  // Service Approval
  @Get('services/pending')
  async getPendingServices(
    @Request() req,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    const limitNum = limit ? parseInt(limit, 10) : 50;
    const offsetNum = offset ? parseInt(offset, 10) : 0;

    await this.adminService.createAuditLog(
      req.user.userId,
      'VIEW_PENDING_SERVICES',
      'services',
    );

    return this.adminService.getPendingServices(limitNum, offsetNum);
  }

  @Patch('services/:id/approve')
  async approveService(
    @Request() req,
    @Param('id', ParseIntPipe) serviceId: number,
  ) {
    return this.adminService.approveService(serviceId, req.user.userId);
  }

  @Patch('services/:id/reject')
  async rejectService(
    @Request() req,
    @Param('id', ParseIntPipe) serviceId: number,
    @Body() dto: RejectServiceDto,
  ) {
    return this.adminService.rejectService(
      serviceId,
      dto.reason,
      req.user.userId,
    );
  }

  // Order Monitoring
  @Get('orders')
  async getAllOrders(
    @Request() req,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('status') status?: JobStatus,
  ) {
    const limitNum = limit ? parseInt(limit, 10) : 50;
    const offsetNum = offset ? parseInt(offset, 10) : 0;

    await this.adminService.createAuditLog(
      req.user.userId,
      'VIEW_ORDERS',
      'orders',
    );

    return this.adminService.getAllOrders(limitNum, offsetNum, status);
  }

  @Get('orders/:id')
  async getOrderDetails(
    @Request() req,
    @Param('id', ParseIntPipe) orderId: number,
  ) {
    await this.adminService.createAuditLog(
      req.user.userId,
      'VIEW_ORDER_DETAILS',
      'order',
      { orderId },
    );

    return this.adminService.getOrderDetails(orderId);
  }

  @Patch('orders/:id/release-payout')
  async releasePayout(
    @Request() req,
    @Param('id', ParseIntPipe) orderId: number,
  ) {
    return this.adminService.releasePayoutHold(orderId, req.user.userId);
  }

  @Patch('orders/:id/mark-paid')
  async markPaid(
    @Request() req,
    @Param('id', ParseIntPipe) orderId: number,
    @Body('notes') notes: string,
  ) {
    return this.adminService.markJobPaidManually(
      orderId,
      req.user.userId,
      notes || 'Manual update',
    );
  }

  // Withdrawal Management
  @Get('withdrawals')
  async getWithdrawals(
    @Request() req,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('status') status?: WithdrawalStatus,
  ) {
    const limitNum = limit ? parseInt(limit, 10) : 50;
    const offsetNum = offset ? parseInt(offset, 10) : 0;

    await this.adminService.createAuditLog(
      req.user.userId,
      'VIEW_WITHDRAWALS',
      'withdrawals',
    );

    return this.adminService.getWithdrawals(limitNum, offsetNum, status);
  }

  @Patch('withdrawals/:id/approve')
  async approveWithdrawal(
    @Request() req,
    @Param('id', ParseIntPipe) withdrawalId: number,
  ) {
    return this.adminService.approveWithdrawal(withdrawalId, req.user.userId);
  }

  @Patch('withdrawals/:id/reject')
  async rejectWithdrawal(
    @Request() req,
    @Param('id', ParseIntPipe) withdrawalId: number,
    @Body() dto: ProcessWithdrawalDto,
  ) {
    return this.adminService.rejectWithdrawal(
      withdrawalId,
      dto.reason || 'No reason provided',
      req.user.userId,
    );
  }

  // Dispute Management
  @Get('disputes')
  async getDisputes(
    @Request() req,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    const limitNum = limit ? parseInt(limit, 10) : 50;
    const offsetNum = offset ? parseInt(offset, 10) : 0;

    await this.adminService.createAuditLog(
      req.user.userId,
      'VIEW_DISPUTES',
      'disputes',
    );

    return this.adminService.getDisputes(limitNum, offsetNum);
  }

  @Patch('disputes/:id/resolve')
  async resolveDispute(
    @Request() req,
    @Param('id', ParseIntPipe) jobId: number,
    @Body() dto: ResolveDisputeDto,
  ) {
    return this.adminService.resolveDispute(
      jobId,
      dto.resolution,
      req.user.userId,
      dto.refundAmount,
      dto.notes,
    );
  }

  // Audit Logs
  @Get('logs')
  async getAuditLogs(
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    const limitNum = limit ? parseInt(limit, 10) : 100;
    const offsetNum = offset ? parseInt(offset, 10) : 0;
    return this.adminService.getAuditLogs(limitNum, offsetNum);
  }
}
