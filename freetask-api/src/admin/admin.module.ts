import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminService } from './admin.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [AdminController],
  providers: [AdminService],
  exports: [AdminService],
})
export class AdminModule {}
