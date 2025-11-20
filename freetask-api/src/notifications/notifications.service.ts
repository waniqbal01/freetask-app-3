import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma, Notification, EmailStatus } from '@prisma/client';
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
    options?: { queueEmail?: boolean; emailSubject?: string; emailBody?: string },
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

    if (options?.queueEmail) {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { email: true },
      });

      if (user?.email) {
        await this.prisma.emailQueue.create({
          data: {
            to: user.email,
            subject: options.emailSubject ?? title,
            body: options.emailBody ?? body,
            status: EmailStatus.PENDING,
          },
        });
      }
    }

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

  async processEmailQueue() {
    const pending = await this.prisma.emailQueue.findMany({
      where: { status: EmailStatus.PENDING },
      orderBy: { createdAt: 'asc' },
      take: 10,
    });

    if (pending.length === 0) {
      this.logger.verbose('No pending emails to process');
      return { processed: 0 };
    }

    this.logger.verbose(
      `Stub processor picked up ${pending.length} emails for sending (not implemented).`,
    );
    return { processed: pending.length };
  }
}
