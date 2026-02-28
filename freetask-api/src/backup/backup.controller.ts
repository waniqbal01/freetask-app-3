import { Controller, Get, Post, UseGuards } from '@nestjs/common';
import { BackupService } from './backup.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '@prisma/client';
import { GetUser } from '../auth/get-user.decorator';

@Controller('admin/backup')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class BackupController {
    constructor(private readonly backupService: BackupService) { }

    @Post('trigger')
    async triggerBackup(@GetUser('userId') _userId: number) {
        const filename = await this.backupService.backupDatabase();
        return { success: true, filename };
    }
}
