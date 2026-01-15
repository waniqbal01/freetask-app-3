import {
    Controller,
    Get,
    Post,
    Body,
    UseGuards,
} from '@nestjs/common';
import { WithdrawalsService } from './withdrawals.service';
import { CreateWithdrawalDto } from './dto/create-withdrawal.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '@prisma/client';

@Controller('withdrawals')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WithdrawalsController {
    constructor(private readonly withdrawalsService: WithdrawalsService) { }

    @Post()
    @Roles(UserRole.FREELANCER)
    create(
        @GetUser('userId') userId: number,
        @Body() dto: CreateWithdrawalDto,
    ) {
        return this.withdrawalsService.createWithdrawal(userId, dto);
    }

    @Get('me')
    @Roles(UserRole.FREELANCER)
    getMyWithdrawals(@GetUser('userId') userId: number) {
        return this.withdrawalsService.getMyWithdrawals(userId);
    }

    @Get('balance')
    @Roles(UserRole.FREELANCER)
    getBalance(@GetUser('userId') userId: number) {
        return this.withdrawalsService.getBalance(userId);
    }
}
