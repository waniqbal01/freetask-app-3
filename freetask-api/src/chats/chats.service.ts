import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMessageDto } from './dto/create-message.dto';
import { ChatMessageDto } from './dto/chat-message.dto';
import { ChatThreadDto } from './dto/chat-thread.dto';

@Injectable()
export class ChatsService {
  constructor(private readonly prisma: PrismaService) { }

  async listThreads(
    userId: number,
    role: UserRole,
    pagination?: { limit?: number; offset?: number },
  ): Promise<ChatThreadDto[]> {
    const take = Math.min(Math.max(pagination?.limit ?? 20, 1), 50);
    const skip = Math.max(pagination?.offset ?? 0, 0);

    const jobs = await this.prisma.job.findMany({
      where:
        role === UserRole.ADMIN
          ? {}
          : {
            OR: [{ clientId: userId }, { freelancerId: userId }],
          },
      include: {
        client: {
          select: { id: true, name: true },
        },
        freelancer: {
          select: { id: true, name: true },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
      orderBy: { updatedAt: 'desc' },
      take,
      skip,
    });

    return jobs.map((job) => {
      const participantName = job.clientId === userId ? job.freelancer.name : job.client.name;
      const participantId = job.clientId === userId ? job.freelancerId : job.clientId;

      // Calculate unread count - cast to any to work around Prisma types
      const messages = job.messages as any[];
      const unreadCount = messages.filter(
        (msg: any) => msg.senderId !== userId && !msg.readAt
      ).length;

      const lastMsg = messages[0] as any;
      return {
        id: job.id,
        jobTitle: job.title,
        participantName,
        participantId,
        lastMessage: lastMsg?.content ?? null,
        lastAt: lastMsg?.createdAt ?? job.updatedAt,
        jobStatus: job.status,
        unreadCount,
      } satisfies ChatThreadDto;
    });
  }

  async listMessages(
    jobId: number,
    userId: number,
    role: UserRole,
    pagination?: { limit?: number; offset?: number },
  ): Promise<ChatMessageDto[]> {
    await this.ensureJobParticipant(jobId, userId, role);
    const take = Math.min(Math.max(pagination?.limit ?? 50, 1), 200);
    const skip = Math.max(pagination?.offset ?? 0, 0);
    const messages = await this.prisma.chatMessage.findMany({
      where: { jobId },
      orderBy: { createdAt: 'desc' },
      include: {
        sender: {
          select: { id: true, name: true },
        },
      },
      take,
      skip,
    });

    return messages
      .reverse()
      .map((message) => {
        const msg = message as any; // Cast to bypass Prisma types
        return {
          id: msg.id,
          jobId: msg.jobId,
          senderId: msg.sender.id,
          senderName: msg.sender.name,
          content: msg.content,
          type: msg.type,
          attachmentUrl: msg.attachmentUrl,
          createdAt: msg.createdAt,
          status: msg.status || 'SENT',
          deliveredAt: msg.deliveredAt || null,
          readAt: msg.readAt || null,
          replyToId: msg.replyToId || null,
        } satisfies ChatMessageDto;
      });
  }

  async postMessage(
    jobId: number,
    userId: number,
    role: UserRole,
    dto: CreateMessageDto,
  ): Promise<ChatMessageDto> {
    // Validate: Content is required UNLESS an attachment is provided
    if ((!dto.content || dto.content.trim() === '') && !dto.attachmentUrl) {
      throw new BadRequestException('Mesej atau lampiran diperlukan.');
    }

    const validatedContent: string = dto.content ?? '';

    await this.ensureJobParticipant(jobId, userId, role);
    const message = await this.prisma.$transaction(async (tx) => {
      const createdMessage = await tx.chatMessage.create({
        data: {
          content: validatedContent,
          type: dto.type ?? 'text',
          attachmentUrl: dto.attachmentUrl,
          jobId,
          senderId: userId,
        },
        include: {
          sender: {
            select: { id: true, name: true },
          },
        },
      });

      await tx.job.update({
        where: { id: jobId },
        data: { updatedAt: new Date() },
      });

      return createdMessage;
    });

    // Cast to any to work around Prisma types
    const msg = message as any;
    return {
      id: msg.id,
      jobId: msg.jobId,
      senderId: msg.sender.id,
      senderName: msg.sender.name,
      content: msg.content,
      type: msg.type,
      attachmentUrl: msg.attachmentUrl,
      createdAt: msg.createdAt,
      status: msg.status || 'SENT',
      deliveredAt: msg.deliveredAt || null,
      readAt: msg.readAt || null,
      replyToId: msg.replyToId || null,
    } satisfies ChatMessageDto;
  }

  private async ensureJobParticipant(jobId: number, userId: number, role: UserRole) {
    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) {
      throw new NotFoundException('Job not found');
    }
    if (role !== UserRole.ADMIN && job.clientId !== userId && job.freelancerId !== userId) {
      throw new ForbiddenException('You are not part of this job');
    }
  }

  // New methods for WebSocket features

  async getMessage(messageId: number) {
    return this.prisma.chatMessage.findUnique({
      where: { id: messageId },
      include: {
        sender: {
          select: { id: true, name: true },
        },
      },
    });
  }

  async markMessageDelivered(messageId: number, userId: number) {
    const message = await this.prisma.chatMessage.findUnique({
      where: { id: messageId },
      include: { job: true },
    });

    if (!message) {
      throw new NotFoundException('Message not found');
    }

    // Only recipient can mark as delivered
    if (message.senderId === userId) {
      return message;
    }

    return this.prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        deliveredAt: new Date(),
      } as any, // Type cast to bypass Prisma validation
    });
  }

  async markMessageRead(messageId: number, userId: number) {
    const message = await this.prisma.chatMessage.findUnique({
      where: { id: messageId },
      include: { job: true },
    });

    if (!message) {
      throw new NotFoundException('Message not found');
    }

    // Only recipient can mark as read
    if (message.senderId === userId) {
      return message;
    }

    const msg = message as any;
    return this.prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        readAt: new Date(),
        deliveredAt: msg.deliveredAt || new Date(),
      } as any, // Type cast to bypass Prisma validation
    });
  }

  async markChatRead(jobId: number, userId: number) {
    // Use raw query to bypass Prisma type checking
    const result = await this.prisma.$executeRaw`
      UPDATE "ChatMessage"
      SET "readAt" = NOW()
      WHERE "jobId" = ${jobId}
        AND "senderId" != ${userId}
        AND "readAt" IS NULL
    `;

    return { count: result };
  }
}
