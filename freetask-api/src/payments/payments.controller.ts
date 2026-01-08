import {
    Controller,
    Get,
    Post,
    Body,
    Param,
    UseGuards,
    ParseIntPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PaymentsService } from './payments.service';
import { CreatePaymentDto, VerifyPaymentDto } from './dto/payment.dto';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('payments')
@UseGuards(JwtAuthGuard)
export class PaymentsController {
    constructor(private readonly paymentsService: PaymentsService) { }

    @Post('create')
    async createPayment(@Body() dto: CreatePaymentDto) {
        return this.paymentsService.createPayment(dto);
    }

    @Post('verify')
    async verifyPayment(@Body() dto: VerifyPaymentDto) {
        return this.paymentsService.verifyPayment(dto);
    }

    @Get('job/:jobId')
    async getPaymentByJobId(@Param('jobId', ParseIntPipe) jobId: number) {
        return this.paymentsService.getPaymentByJobId(jobId);
    }

    @Post('refund/:jobId')
    @Roles('ADMIN')
    @UseGuards(RolesGuard)
    async refundPayment(@Param('jobId', ParseIntPipe) jobId: number) {
        return this.paymentsService.refundPayment(jobId);
    }

    @Post('webhook')
    async handleWebhook(@Body() payload: any) {
        return this.paymentsService.handleWebhook(payload);
    }
}
