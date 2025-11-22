import { Controller, Get } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async getHealth() {
    const dbStatus = await this.prisma.$queryRaw`SELECT 1 as ok`;
    return { status: 'ok', db: Boolean(dbStatus) };
  }
}
