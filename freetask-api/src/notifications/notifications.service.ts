import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterTokenDto } from './dto/register-token.dto';
import {
  CreateNotificationDto,
  SendNotificationDto,
} from './dto/notification.dto';

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

  async markChatNotificationsAsRead(userId: number, conversationId: number) {
    try {
      // Find all unread chat notifications for this user and conversation
      const notifications = await this.prisma.notification.findMany({
        where: {
          userId,
          type: 'CHAT_MESSAGE',
          read: false,
        },
      });

      const targetNotificationIds = notifications
        .filter((n) => {
          if (!n.data) return false;
          try {
            const dataObj = typeof n.data === 'string' ? JSON.parse(n.data) : n.data;
            return dataObj.conversationId === conversationId.toString();
          } catch (e) {
            return false;
          }
        })
        .map((n) => n.id);

      if (targetNotificationIds.length > 0) {
        return await this.prisma.notification.updateMany({
          where: {
            id: { in: targetNotificationIds },
          },
          data: { read: true },
        });
      }
      return { count: 0 };
    } catch (error) {
      this.logger.error('Failed to mark chat notifications as read', error);
      return { count: 0 };
    }
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

    // --- Spam Control (Rate Limiting) ---
    // Pre-flight check: Prevent sending the exact same type of push notification
    // within a 3-second window (e.g., when 5 messages arrive at the same time).
    const threeSecondsAgo = new Date(Date.now() - 3000);
    const recentDuplicatePush = await this.prisma.notification.findFirst({
      where: {
        userId: dto.userId,
        type: dto.type,
        createdAt: { gte: threeSecondsAgo },
        id: { not: notification.id }, // Ignore the one we just saved
      },
      select: { id: true },
    });

    if (recentDuplicatePush && dto.type) {
      this.logger.log(`[SPAM CONTROL] Suppressing push dispatch for ${dto.type} to user ${dto.userId} (too rapid)`);
      return notification; // Return DB-saved notification without vibrating the user
    }

    // Get user's device tokens
    const tokens = await this.prisma.deviceToken.findMany({
      where: { userId: dto.userId },
    });

    if (tokens.length > 0) {
      // Fire and forget push notification to avoid blocking the API response
      this.dispatchPushNotifications(tokens, dto).catch((error) => {
        this.logger.error('Unhandled error in dispatchPushNotifications', error);
      });
    }

    return notification;
  }

  private async dispatchPushNotifications(tokens: any[], dto: SendNotificationDto) {
    try {
      const admin = require('firebase-admin');
      // Check if firebase is initialized
      if (admin.apps.length > 0) {
        const messages = tokens.map((t) => {
          const isAndroid = t.platform?.toLowerCase() === 'android';

          const payloadData: Record<string, string> = {
            title: String(dto.title),
            body: String(dto.body),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          };

          if (dto.data) {
            Object.entries(dto.data).forEach(([key, value]) => {
              if (value !== undefined && value !== null) {
                payloadData[key] = String(value);
              }
            });
          }

          if (isAndroid) {
            // Android: Data + Notification message to ensure OS delivers background notifications
            return {
              token: t.token,
              notification: {
                title: dto.title,
                body: dto.body,
              },
              data: payloadData,
              android: {
                priority: 'high',
                notification: {
                  channelId: 'freetask_notifications',
                  sound: 'default',
                },
              },
              fcmOptions: {
                analyticsLabel: String(dto.type || 'freetask_notification').substring(0, 50),
              },
            };
          }

          // iOS/Web: Standard notification + data (APNs correctly handles background wakes)
          return {
            token: t.token,
            notification: {
              title: dto.title,
              body: dto.body,
            },
            data: payloadData,
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
            fcmOptions: {
              analyticsLabel: String(dto.type || 'freetask_notification').substring(0, 50),
            },
          };
        });

        const response = await admin.messaging().sendEach(messages);
        this.logger.log(
          `Sent notifications: ${response.successCount} success, ${response.failureCount} failure`,
        );

        // --- Error Handling (Invalid/Expired Tokens Cleanup) ---
        if (response.failureCount > 0) {
          const failedTokens: string[] = [];
          response.responses.forEach((resp: any, idx: number) => {
            if (!resp.success && resp.error) {
              const errorCode = resp.error.code;
              // Detect unregistered or invalid tokens and queue them for deletion
              if (
                errorCode === 'messaging/invalid-registration-token' ||
                errorCode === 'messaging/registration-token-not-registered'
              ) {
                failedTokens.push(tokens[idx].token);
              }
            }
          });

          if (failedTokens.length > 0) {
            this.logger.warn(`Removing ${failedTokens.length} expired/invalid device tokens from DB.`);
            await this.prisma.deviceToken.deleteMany({
              where: { token: { in: failedTokens } },
            }).catch((err) => {
              this.logger.error('Error cleaning up invalid tokens', err);
            });
          }
        }
      } else {
        this.logger.warn(
          'Firebase Admin not initialized, skipping push notification',
        );
      }
    } catch (error) {
      this.logger.error('Error sending push notification', error);
    }
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
