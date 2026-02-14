import { Controller, Get, Query, Res, Logger } from '@nestjs/common';
import { Response } from 'express';
import { PaymentsService } from './payments.service';

@Controller('payments')
export class PaymentsCallbackController {
  private readonly logger = new Logger(PaymentsCallbackController.name);

  constructor(private readonly paymentsService: PaymentsService) {}

  @Get('callback')
  async handleCallback(@Query() query: any, @Res() res: Response) {
    const billId = query.billplz?.id || query.id;
    const paid = query.billplz?.paid === 'true' || query.paid === 'true';

    this.logger.log(`Callback received: billId=${billId}, paid=${paid}`);

    try {
      if (!billId) {
        return res.redirect(
          `${process.env.APP_URL || 'http://localhost:8080'}?payment=error`,
        );
      }

      // Verify and complete payment if needed (Double check with Billplz API)
      // This ensures state is synced even if webhook failed (common in localhost)
      const payment =
        await this.paymentsService.checkAndCompletePayment(billId);

      if (!payment) {
        this.logger.warn(`Payment not found for bill ${billId}`);
        return res.redirect(
          `${process.env.APP_URL || 'http://localhost:8080'}?payment=error`,
        );
      }

      // Redirect to job detail with payment status
      const redirectUrl =
        payment.status === 'COMPLETED'
          ? `${process.env.APP_URL || 'http://localhost:8080'}/jobs/${payment.jobId}?payment=success`
          : `${process.env.APP_URL || 'http://localhost:8080'}/jobs/${payment.jobId}?payment=failed`;

      this.logger.log(`Redirecting to: ${redirectUrl}`);
      return res.redirect(redirectUrl);
    } catch (error) {
      this.logger.error('Error handling callback', error);
      return res.redirect(
        `${process.env.APP_URL || 'http://localhost:8080'}?payment=error`,
      );
    }
  }
}
