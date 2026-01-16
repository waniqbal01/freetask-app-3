import {
    Controller,
    Get,
    Post,
    Patch,
    Delete,
    Body,
    Param,
    Query,
    UseGuards,
    Request,
    ParseIntPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { NotificationsService } from './notifications.service';
import { RegisterTokenDto } from './dto/register-token.dto';
import { SendNotificationDto } from './dto/notification.dto';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
    constructor(private readonly notificationsService: NotificationsService) { }

    @Post('register-token')
    async registerToken(@Request() req, @Body() dto: RegisterTokenDto) {
        return this.notificationsService.registerToken(req.user.userId, dto);
    }

    @Get()
    async getNotifications(
        @Request() req,
        @Query('limit') limit?: string,
        @Query('offset') offset?: string,
    ) {
        const limitNum = limit ? parseInt(limit, 10) : 50;
        const offsetNum = offset ? parseInt(offset, 10) : 0;
        return this.notificationsService.getUserNotifications(
            req.user.userId,
            limitNum,
            offsetNum,
        );
    }

    @Patch(':id/read')
    async markAsRead(@Request() req, @Param('id', ParseIntPipe) id: number) {
        return this.notificationsService.markAsRead(req.user.userId, id);
    }

    @Patch('read-all')
    async markAllAsRead(@Request() req) {
        return this.notificationsService.markAllAsRead(req.user.userId);
    }

    @Get('unread-count')
    async getUnreadCount(@Request() req) {
        const count = await this.notificationsService.getUnreadCount(req.user.userId);
        return { count };
    }

    @Post('send')
    @Roles('ADMIN')
    @UseGuards(RolesGuard)
    async sendNotification(@Body() dto: SendNotificationDto) {
        return this.notificationsService.sendNotification(dto);
    }

    @Delete('token/:token')
    async deleteToken(@Request() req, @Param('token') token: string) {
        return this.notificationsService.deleteToken(req.user.userId, token);
    }
}
