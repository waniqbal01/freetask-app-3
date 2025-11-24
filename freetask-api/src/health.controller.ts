import { Controller, Get } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';

// TODO: Consider adding authentication or rate limiting in production
// to prevent health endpoint abuse or information disclosure
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) { }

  @Get()
  async getHealth() {
    // Verify DB connection without exposing query details
    await this.prisma.$queryRaw`SELECT 1 as ok`;
    return { status: 'ok' };
  }
}
