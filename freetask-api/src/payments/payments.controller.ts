import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
  ParseIntPipe,
  Headers as RequestHeaders,
  Req,
  Logger,
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PaymentsService } from './payments.service';
import { CreatePaymentDto, VerifyPaymentDto } from './dto/payment.dto';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('payments')
export class PaymentsController {
  private readonly logger = new Logger(PaymentsController.name);

  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('create')
  @UseGuards(JwtAuthGuard)
  async createPayment(@Body() dto: CreatePaymentDto) {
    try {
      return await this.paymentsService.createPayment(dto);
    } catch (error) {
      this.logger.error(
        `❌ Payment creation failed: ${error.message}`,
        error.stack,
      );
      // DEBUG: Return 400 to bypass generic 500 error handling in frontend
      throw new BadRequestException(`Payment Failed: ${error.message}`);
    }
  }

  @Post('verify')
  @UseGuards(JwtAuthGuard)
  async verifyPayment(@Body() dto: VerifyPaymentDto) {
    return this.paymentsService.verifyPayment(dto);
  }

  @Get('job/:jobId')
  @UseGuards(JwtAuthGuard)
  async getPaymentByJobId(@Param('jobId', ParseIntPipe) jobId: number) {
    return this.paymentsService.getPaymentByJobId(jobId);
  }

  @Post('refund/:jobId')
  @Roles('ADMIN')
  @UseGuards(JwtAuthGuard, RolesGuard)
  async refundPayment(@Param('jobId', ParseIntPipe) jobId: number) {
    return this.paymentsService.refundPayment(jobId);
  }

  // ⚠️ IMPORTANT: Webhook endpoint must be PUBLIC (no auth guard)
  // Billplz callbacks don't include JWT tokens
  @Post('webhook')
  async handleWebhook(
    @Body() payload: any,
    @RequestHeaders('x-signature') signature: string,
  ) {
    this.logger.log('📥 Received Billplz webhook callback');
    this.logger.debug(`Webhook payload: ${JSON.stringify(payload, null, 2)}`);
    return this.paymentsService.handleWebhook(payload, signature || '');
  }

  @Post('retry/:jobId')
  @UseGuards(JwtAuthGuard)
  async retryPayment(@Param('jobId', ParseIntPipe) jobId: number) {
    return this.paymentsService.retryPayment(jobId);
  }

  @Get('history')
  @UseGuards(JwtAuthGuard)
  async getPaymentHistory(@Req() req: any) {
    const userId = req.user?.userId;
    return this.paymentsService.getPaymentHistory(userId);
  }
}
