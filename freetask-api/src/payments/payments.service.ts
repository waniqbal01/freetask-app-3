import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePaymentDto, VerifyPaymentDto } from './dto/payment.dto';

@Injectable()
export class PaymentsService {
    private readonly logger = new Logger(PaymentsService.name);

    constructor(private prisma: PrismaService) { }

    async createPayment(dto: CreatePaymentDto) {
        // Check if job exists
        const job = await this.prisma.job.findUnique({
            where: { id: dto.jobId },
        });

        if (!job) {
            throw new NotFoundException('Job not found');
        }

        // Check if payment already exists
        const existing = await this.prisma.payment.findUnique({
            where: { jobId: dto.jobId },
        });

        if (existing) {
            throw new BadRequestException('Payment already exists for this job');
        }

        // Create payment record
        const payment = await this.prisma.payment.create({
            data: {
                jobId: dto.jobId,
                amount: job.amount,
                paymentMethod: dto.paymentMethod,
                paymentGateway: dto.paymentGateway || 'manual',
                status: 'PENDING',
            },
        });

        this.logger.log(`Created payment ${payment.id} for job ${dto.jobId}`);

        // TODO: Integrate with actual payment gateway (Stripe/Razorpay)
        // For now, return payment intent placeholder
        return {
            payment,
            paymentIntent: {
                id: `pi_${Date.now()}`,
                amount: job.amount.toString(),
                currency: 'MYR',
                status: 'requires_payment_method',
            },
        };
    }

    async verifyPayment(dto: VerifyPaymentDto) {
        const payment = await this.prisma.payment.findUnique({
            where: { jobId: dto.jobId },
        });

        if (!payment) {
            throw new NotFoundException('Payment not found');
        }

        // TODO: Verify with actual payment gateway
        // For now, just update the payment status
        const updated = await this.prisma.payment.update({
            where: { id: payment.id },
            data: {
                status: 'COMPLETED',
                transactionId: dto.transactionId,
            },
        });

        this.logger.log(`Payment ${payment.id} verified with transaction ${dto.transactionId}`);

        return updated;
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
        const payment = await this.prisma.payment.findUnique({
            where: { jobId },
        });

        if (!payment) {
            throw new NotFoundException('Payment not found');
        }

        if (payment.status !== 'COMPLETED') {
            throw new BadRequestException('Only completed payments can be refunded');
        }

        // TODO: Process refund with payment gateway
        const updated = await this.prisma.payment.update({
            where: { id: payment.id },
            data: {
                status: 'REFUNDED',
            },
        });

        this.logger.log(`Payment ${payment.id} refunded`);

        return updated;
    }

    async handleWebhook(payload: any) {
        // TODO: Implement webhook handling for payment gateway
        this.logger.log('Payment webhook received', payload);
        return { received: true };
    }
}
