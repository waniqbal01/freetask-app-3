import { Controller, Get, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { PrismaService } from './prisma/prisma.service';
import { JwtAuthGuard } from './auth/jwt-auth.guard';
import { RolesGuard } from './auth/roles.guard';
import { Roles } from './auth/roles.decorator';
import { UserRole } from '@prisma/client';

// Secured with JWT auth and rate limited for production
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) { }

  // Public health check for load balancers and monitoring tools
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @Get()
  getPublicHealth() {
    return { status: 'ok' };
  }

  // Detailed health check with DB probe, requires ADMIN auth
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Get('detailed')
  async getDetailedHealth() {
    // Verify DB connection without exposing query details
    await this.prisma.$queryRaw`SELECT 1 as ok`;
    return { status: 'ok', database: 'connected' };
  }
}
