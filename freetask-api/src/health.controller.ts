import { Controller, Get, Inject, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { PrismaService } from './prisma/prisma.service';
import { JwtAuthGuard } from './auth/jwt-auth.guard';
import { RolesGuard } from './auth/roles.guard';
import { Roles } from './auth/roles.decorator';
import { UserRole } from '@prisma/client';

/**
 * Health Check Controller
 * 
 * PUBLIC /health endpoint:
 * - Lightweight, instant response
 * - No database/service dependencies
 * - Used for wake-up and load balancer checks
 * 
 * ADMIN /health/detailed endpoint:
 * - Includes database connectivity check
 * - Requires authentication
 * - For admin diagnostics only
 */
@Controller('health')
export class HealthController {
  // No constructor dependencies - /health is instant!
  // PrismaService only injected on-demand for /health/detailed

  // Public health check for load balancers and monitoring tools
  // CRITICAL: This endpoint must be INSTANT (no DB, no auth, no heavy init)
  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @Get()
  getPublicHealth() {
    return { 
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'freetask-api'
    };
  }

  // Detailed health check with DB probe, requires ADMIN auth
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Get('detailed')
  async getDetailedHealth(@Inject(PrismaService) prisma: PrismaService) {
    // Lazy inject PrismaService - only used when needed
    // Verify DB connection without exposing query details
    await prisma.$queryRaw`SELECT 1 as ok`;
    return { 
      status: 'ok', 
      database: 'connected',
      timestamp: new Date().toISOString()
    };
  }
}
