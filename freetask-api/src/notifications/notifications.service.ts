import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterTokenDto } from './dto/register-token.dto';
import { CreateNotificationDto, SendNotificationDto } from './dto/notification.dto';

@Injectable()
export class NotificationsService {
    private readonly logger = new Logger(NotificationsService.name);

    constructor(private prisma: PrismaService) { }

    async registerToken(userId: number, dto: RegisterTokenDto) {
        // Check if token already exists
        const existing = await this.prisma.deviceToken.findUnique({
            where: { token: dto.token },
        });

        if (existing) {
            // Update if token belongs to different user
            if (existing.userId !== userId) {
                return this.prisma.deviceToken.update({
                    where: { token: dto.token },
                    data: {
                        userId,
                        platform: dto.platform,
                        updatedAt: new Date(),
                    },
                });
            }
            return existing;
        }

        // Create new token
        return this.prisma.deviceToken.create({
            data: {
                userId,
                token: dto.token,
                platform: dto.platform,
            },
        });
    }

    async getUserNotifications(userId: number, limit = 50, offset = 0) {
        const notifications = await this.prisma.notification.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
            take: limit,
            skip: offset,
        });

        const total = await this.prisma.notification.count({
            where: { userId },
        });

        const unreadCount = await this.prisma.notification.count({
            where: { userId, read: false },
        });

        return {
            notifications,
            total,
            unreadCount,
        };
    }

    async markAsRead(userId: number, notificationId: number) {
        const notification = await this.prisma.notification.findUnique({
            where: { id: notificationId },
        });

        if (!notification) {
            throw new NotFoundException('Notification not found');
        }

        if (notification.userId !== userId) {
            throw new NotFoundException('Notification not found');
        }

        return this.prisma.notification.update({
            where: { id: notificationId },
            data: { read: true },
        });
    }

    async markAllAsRead(userId: number) {
        return this.prisma.notification.updateMany({
            where: { userId, read: false },
            data: { read: true },
        });
    }

    async getUnreadCount(userId: number): Promise<number> {
        return this.prisma.notification.count({
            where: { userId, read: false },
        });
    }

    async createNotification(dto: CreateNotificationDto) {
        return this.prisma.notification.create({
            data: {
                userId: dto.userId,
                title: dto.title,
                body: dto.body,
                type: dto.type,
                data: dto.data,
            },
        });
    }

    async sendNotification(dto: SendNotificationDto) {
        // Create notification in database
        const notification = await this.createNotification({
            userId: dto.userId,
            title: dto.title,
            body: dto.body,
            data: dto.data,
        });

        // Get user's device tokens
        const tokens = await this.prisma.deviceToken.findMany({
            where: { userId: dto.userId },
        });

        if (tokens.length > 0) {
            try {
                const admin = require('firebase-admin');
                // Check if firebase is initialized
                if (admin.apps.length > 0) {
                    const messages = tokens.map((t) => ({
                        token: t.token,
                        notification: {
                            title: dto.title,
                            body: dto.body,
                        },
                        data: dto.data ? {
                            ...dto.data,
                            click_action: 'FLUTTER_NOTIFICATION_CLICK',
                        } : undefined,
                        android: {
                            priority: 'high',
                            notification: {
                                sound: 'default',
                                channelId: 'default_channel',
                            },
                        },
                        apns: {
                            payload: {
                                aps: {
                                    sound: 'default',
                                    badge: 1,
                                },
                            },
                        },
                    }));

                    const response = await admin.messaging().sendEach(messages);
                    this.logger.log(
                        `Sent notifications: ${response.successCount} success, ${response.failureCount} failure`,
                    );

                    // Clean up invalid tokens
                    if (response.failureCount > 0) {
                        const failedTokens = response.responses
                            .map((resp, idx) => (!resp.success ? tokens[idx].token : null))
                            .filter((t) => t !== null);

                        // For now just log, implemented remove logic separately or here
                        this.logger.warn(`Failed tokens: ${failedTokens.join(', ')}`);
                    }
                } else {
                    this.logger.warn('Firebase Admin not initialized, skipping push notification');
                }
            } catch (error) {
                this.logger.error('Error sending push notification', error);
            }
        }

        return notification;
    }

    async deleteToken(userId: number, token: string) {
        const deviceToken = await this.prisma.deviceToken.findUnique({
            where: { token },
        });

        if (!deviceToken || deviceToken.userId !== userId) {
            throw new NotFoundException('Token not found');
        }

        return this.prisma.deviceToken.delete({
            where: { token },
        });
    }
}
