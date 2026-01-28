import { Module } from '@nestjs/common';
import { JobsService } from './jobs.service';
import { JobsController } from './jobs.controller';
import { RolesGuard } from '../auth/roles.guard';
import { EscrowService } from '../escrow/escrow.service';
import { ChatsModule } from '../chats/chats.module';
import { NotificationsModule } from '../notifications/notifications.module';

import { PaymentsModule } from '../payments/payments.module';

@Module({
  imports: [ChatsModule, NotificationsModule, PaymentsModule],
  controllers: [JobsController],
  providers: [JobsService, RolesGuard, EscrowService],
})
export class JobsModule { }
