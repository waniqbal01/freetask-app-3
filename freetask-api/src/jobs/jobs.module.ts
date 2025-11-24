import { Module } from '@nestjs/common';
import { JobsService } from './jobs.service';
import { JobsController } from './jobs.controller';
import { RolesGuard } from '../auth/roles.guard';

@Module({
  controllers: [JobsController],
  providers: [JobsService, RolesGuard],
})
export class JobsModule {}
