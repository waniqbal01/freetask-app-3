import {
    Controller,
    Get,
    Query,
    UseGuards,
    Request,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminService } from './admin.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminController {
    constructor(private readonly adminService: AdminService) { }

    @Get('analytics')
    async getAnalytics(@Request() req) {
        await this.adminService.createAuditLog(
            req.user.userId,
            'VIEW_ANALYTICS',
            'analytics',
        );
        return this.adminService.getAnalytics();
    }

    @Get('users')
    async getUsers(
        @Request() req,
        @Query('limit') limit?: string,
        @Query('offset') offset?: string,
    ) {
        const limitNum = limit ? parseInt(limit, 10) : 50;
        const offsetNum = offset ? parseInt(offset, 10) : 0;

        await this.adminService.createAuditLog(
            req.user.userId,
            'VIEW_USERS',
            'users',
        );

        return this.adminService.getUsers(limitNum, offsetNum);
    }

    @Get('logs')
    async getAuditLogs(
        @Query('limit') limit?: string,
        @Query('offset') offset?: string,
    ) {
        const limitNum = limit ? parseInt(limit, 10) : 100;
        const offsetNum = offset ? parseInt(offset, 10) : 0;
        return this.adminService.getAuditLogs(limitNum, offsetNum);
    }

    @Get('stats')
    async getSystemStats(@Request() req) {
        await this.adminService.createAuditLog(
            req.user.userId,
            'VIEW_STATS',
            'stats',
        );
        return this.adminService.getSystemStats();
    }
}
