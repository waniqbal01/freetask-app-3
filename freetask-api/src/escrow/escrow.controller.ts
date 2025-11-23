import { Controller, Get, Param, ParseIntPipe, Post, UseGuards } from '@nestjs/common';
import { EscrowService } from './escrow.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { UserRole } from '@prisma/client';

@Controller('escrow')
@UseGuards(JwtAuthGuard)
export class EscrowController {
  constructor(private readonly escrowService: EscrowService) {}

  @Get(':jobId')
  getForJob(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.escrowService.getForUser(jobId, userId, role);
  }

  @Post(':jobId/hold')
  hold(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.escrowService.hold(jobId, role);
  }

  @Post(':jobId/release')
  release(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.escrowService.release(jobId, role);
  }

  @Post(':jobId/refund')
  refund(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.escrowService.refund(jobId, role);
  }
}
