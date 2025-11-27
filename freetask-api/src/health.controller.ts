import { Controller, Get, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { PrismaService } from './prisma/prisma.service';
import { JwtAuthGuard } from './auth/jwt-auth.guard';

// Secured with JWT auth and rate limited for production
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) { }

  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Get()
  async getHealth() {
    // Verify DB connection without exposing query details
    await this.prisma.$queryRaw`SELECT 1 as ok`;
    return { status: 'ok' };
  }
}
