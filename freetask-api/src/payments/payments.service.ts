import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EscrowService } from '../escrow/escrow.service';
import { BillplzService } from './billplz.service';
import { CreatePaymentDto, VerifyPaymentDto } from './dto/payment.dto';

@Injectable()
export class PaymentsService {
    private readonly logger = new Logger(PaymentsService.name);

    constructor(
        private prisma: PrismaService,
        private billplzService: BillplzService,
        private escrowService: EscrowService,
    ) { }

    async createPayment(dto: CreatePaymentDto) {
        // Check if job exists
        const job = await this.prisma.job.findUnique({
            where: { id: dto.jobId },
            include: {
                client: true,
                service: true
            }
        });

        if (!job) {
            throw new NotFoundException('Job not found');
        }

        // Check if payment already exists
        const existing = await this.prisma.payment.findUnique({
            where: { jobId: dto.jobId },
        });

        if (existing && existing.status === 'COMPLETED') {
            throw new BadRequestException('Payment already completed for this job');
        }

        // Calculate amount in cents (MYR)
        const amountInCents = Math.round(Number(job.amount) * 100);

        // Call Billplz API
        const billplzResponse = await this.billplzService.createCollection(
            `Payment for Job #${job.id}: ${job.title}`,
            amountInCents,
            job.client.email,
            job.client.name,
            `Payment for service: ${job.service.title}`,
            `${process.env.API_URL || 'http://localhost:3000'}/payments/callback`, // Helper callback page? Or just webhook
            `${process.env.APP_URL || 'http://localhost:8080'}/jobs/${job.id}`, // Redirect back to app
        );

        // Create or Update payment record
        // If pending payment exists, we might want to update it or create new one.
        // For simplicity, let's assume one payment record per job.
        let payment;
        if (existing) {
            payment = await this.prisma.payment.update({
                where: { id: existing.id },
                data: {
                    paymentGateway: 'billplz',
                    transactionId: billplzResponse.id, // Save Billplz Bill ID
                    status: 'PENDING',
                }
            });
        } else {
            payment = await this.prisma.payment.create({
                data: {
                    jobId: dto.jobId,
                    amount: job.amount,
                    paymentMethod: dto.paymentMethod,
                    paymentGateway: 'billplz',
                    transactionId: billplzResponse.id,
                    status: 'PENDING',
                },
            });
        }

        this.logger.log(`Created Billplz bill ${billplzResponse.id} for job ${dto.jobId}`);

        return {
            payment,
            url: billplzResponse.url, // Return Billplz payment page URL
        };
    }

    async verifyPayment(dto: VerifyPaymentDto) {
        // This might be used for manual verification or checking status
        // Implementation depends on need. For now, webhook handles completion.
        const payment = await this.prisma.payment.findUnique({
            where: { jobId: dto.jobId },
        });

        if (!payment) {
            throw new NotFoundException('Payment not found');
        }

        return payment;
    }

    async getPaymentByJobId(jobId: number) {
        const payment = await this.prisma.payment.findUnique({
            where: { jobId },
            include: {
                job: {
                    include: {
                        service: true,
                        client: {
                            select: {
                                id: true,
                                name: true,
                                email: true,
                            },
                        },
                        freelancer: {
                            select: {
                                id: true,
                                name: true,
                                email: true,
                            },
                        },
                    },
                },
            },
        });

        if (!payment) {
            throw new NotFoundException('Payment not found');
        }

        return payment;
    }

    async refundPayment(jobId: number) {
        // Logic for refunding payment (maybe call EscrowService.refund)
        // This is triggered by Admin usually.
        // TODO: Implement actual reversal via Billplz if API supported, otherwise just update record.
        const payment = await this.prisma.payment.findUnique({
            where: { jobId },
        });

        if (!payment || payment.status !== 'COMPLETED') {
            throw new BadRequestException('Cannot refund incomplete payment');
        }

        // This logic should align with EscrowService.refund
        // Currently EscrowService.refund handles the wallet refund.
        // We just update payment status here for record.

        const updated = await this.prisma.payment.update({
            where: { id: payment.id },
            data: {
                status: 'REFUNDED',
            },
        });

        return updated;
    }

    async handleWebhook(payload: any, signature: string) {
        // Verify X-Signature
        const isValid = this.billplzService.verifyXSignature(payload, signature);
        if (!isValid) {
            this.logger.error('Invalid Billplz X-Signature');
            // throw new ForbiddenException('Invalid signature'); // Don't throw to avoid retries if it's security issue?
            return { status: 'failed', message: 'Invalid signature' };
        }

        const billId = payload.id;
        const state = payload.state; // 'paid'

        this.logger.log(`Received webhook for bill ${billId}, state: ${state}`);

        const payment = await this.prisma.payment.findUnique({
            where: { transactionId: billId },
        });

        if (!payment) {
            this.logger.warn(`Payment not found for bill ${billId}`);
            return { status: 'failed', message: 'Payment not found' };
        }

        if (payment.status === 'COMPLETED') {
            this.logger.log(`Payment ${payment.id} already completed`);
            return { status: 'success' };
        }

        if (state === 'paid') {
            // Update Payment Status
            await this.prisma.payment.update({
                where: { id: payment.id },
                data: {
                    status: 'COMPLETED',
                    paymentMethod: 'billplz', // or payload.payment_channel
                },
            });

            // Trigger Escrow Hold
            try {
                await this.escrowService.internalHold(payment.jobId);
                this.logger.log(`Escrow held for job ${payment.jobId}`);
            } catch (error) {
                this.logger.error(`Failed to hold escrow for job ${payment.jobId}`, error);
                // We shouldn't fail the webhook response, but we need to alert admin/logs
            }
        }

        return { status: 'success' };
    }
}
