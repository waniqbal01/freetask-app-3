import { Module } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { PaymentsController } from './payments.controller';
import { EscrowModule } from '../escrow/escrow.module';
import { BillplzService } from './billplz.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
    imports: [PrismaModule, EscrowModule],
    controllers: [PaymentsController],
    providers: [PaymentsService, BillplzService],
    exports: [PaymentsService],
})
export class PaymentsModule { }
