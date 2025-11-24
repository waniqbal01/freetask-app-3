import { Controller, Get } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { PrismaService } from './prisma/prisma.service';

// Rate limited to prevent health endpoint abuse in production
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) { }

  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Get()
  async getHealth() {
    // Verify DB connection without exposing query details
    await this.prisma.$queryRaw`SELECT 1 as ok`;
    return { status: 'ok' };
  }
}
