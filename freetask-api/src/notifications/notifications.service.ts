import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma, Notification } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async notifyUser(
    userId: number,
    type: string,
    title: string,
    body: string,
    metadata?: Prisma.JsonValue,
  ): Promise<Notification> {
    const notification = await this.prisma.notification.create({
      data: {
        userId,
        type,
        title,
        body,
        metadata,
      },
    });

    this.logger.debug(
      `Notification queued for user ${userId}: ${type} - ${title}`,
    );
    this.logger.verbose('TODO: Send email/push notification via provider');

    return notification;
  }

  async listForUser(userId: number): Promise<Notification[]> {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async markAsRead(id: number, userId: number): Promise<Notification> {
    const notification = await this.prisma.notification.findFirst({
      where: { id, userId },
    });

    if (!notification) {
      throw new NotFoundException('Notification not found');
    }

    if (notification.isRead) {
      return notification;
    }

    return this.prisma.notification.update({
      where: { id },
      data: { isRead: true },
    });
  }
}
