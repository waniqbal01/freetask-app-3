import { Module } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentsCallbackController } from './payments-callback.controller';
import { PaymentsService } from './payments.service';
import { BillplzService } from './billplz.service';
import { PrismaModule } from '../prisma/prisma.module';
import { EscrowModule } from '../escrow/escrow.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [PrismaModule, EscrowModule, NotificationsModule],
  controllers: [PaymentsController, PaymentsCallbackController],
  providers: [PaymentsService, BillplzService],
  exports: [PaymentsService, BillplzService],
})
export class PaymentsModule {}
