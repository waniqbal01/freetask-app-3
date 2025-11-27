import { Controller, Get, Param, ParseIntPipe, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { EscrowService } from './escrow.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { UserRole } from '@prisma/client';

@Controller('escrow')
@UseGuards(JwtAuthGuard)
export class EscrowController {
  constructor(private readonly escrowService: EscrowService) { }

  @Get(':jobId')
  getForJob(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.escrowService.getForUser(jobId, userId, role);
  }

  @Post(':jobId/hold')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  hold(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.escrowService.hold(jobId, role);
  }

  @Post(':jobId/release')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  release(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.escrowService.release(jobId, role);
  }

  @Post(':jobId/refund')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  refund(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('role') role: UserRole,
  ) {
    return this.escrowService.refund(jobId, role);
  }
}
