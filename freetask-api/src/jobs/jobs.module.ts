import { Module } from '@nestjs/common';
import { JobsService } from './jobs.service';
import { JobsController } from './jobs.controller';
import { RolesGuard } from '../auth/roles.guard';
import { EscrowService } from '../escrow/escrow.service';

@Module({
  controllers: [JobsController],
  providers: [JobsService, RolesGuard, EscrowService],
})
export class JobsModule {}
