import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UserRole, WithdrawalStatus } from '@prisma/client';
import { CreateWithdrawalDto } from './dto/create-withdrawal.dto';

@Injectable()
export class WithdrawalsService {
    private readonly logger = new Logger(WithdrawalsService.name);

    constructor(private prisma: PrismaService) { }

    async createWithdrawal(userId: number, dto: CreateWithdrawalDto) {
        // Get user's current balance
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { balance: true, role: true },
        });

        if (!user) {
            throw new BadRequestException('User not found');
        }

        if (user.role !== UserRole.FREELANCER) {
            throw new BadRequestException('Only freelancers can request withdrawals');
        }

        if (user.balance < dto.amount) {
            throw new BadRequestException(
                `Insufficient balance. Available: ${user.balance}, Requested: ${dto.amount}`
            );
        }

        // Create withdrawal request
        const withdrawal = await this.prisma.withdrawal.create({
            data: {
                freelancerId: userId,
                amount: dto.amount,
                bankDetails: dto.bankDetails,
                status: WithdrawalStatus.PENDING,
            },
        });

        return withdrawal;
    }

    async getMyWithdrawals(userId: number) {
        return this.prisma.withdrawal.findMany({
            where: { freelancerId: userId },
            orderBy: { createdAt: 'desc' },
            include: {
                processedBy: {
                    select: {
                        id: true,
                        name: true,
                        email: true,
                    },
                },
            },
        });
    }

    async getBalance(userId: number) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { balance: true },
        });

        return { balance: user?.balance || 0 };
    }

    async updateBalanceAfterJobCompletion(freelancerId: number, amount: number) {
        return this.prisma.user.update({
            where: { id: freelancerId },
            data: {
                balance: {
                    increment: amount,
                },
            },
        });
    }
}
