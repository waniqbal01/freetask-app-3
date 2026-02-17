import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
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

    const conversations = await this.prisma.conversation.findMany({
      where: {
        participants: { some: { id: userId } },
      },
      include: {
        participants: {
          select: { id: true, name: true, avatarUrl: true },
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

    return conversations.map((convo) => {
      const otherParticipant =
        convo.participants.find((p) => p.id !== userId) ||
        convo.participants[0];
      const participantName = otherParticipant?.name || 'Unknown User';
      const participantId = otherParticipant?.id || 0;
      const participantAvatarUrl = otherParticipant?.avatarUrl || null;

      // Unread count: We can implement a more efficient query later
      // For now, let's keep it 0 or basic check if needed
      const unreadCount = 0;

      const lastMsg = convo.messages[0];
      return {
        id: convo.id,
        jobTitle: 'Conversation',
        participantName,
        participantId,
        participantAvatarUrl,
        lastMessage:
          lastMsg?.content ?? (lastMsg?.attachmentUrl ? 'Attachment' : null),
        lastAt: lastMsg?.createdAt ?? convo.updatedAt,
        jobStatus: 'ACTIVE' as any,
        unreadCount,
      } satisfies ChatThreadDto;
    });
  }

  async listMessages(
    conversationId: number,
    userId: number,
    role: UserRole,
    pagination?: { limit?: number; offset?: number },
  ): Promise<ChatMessageDto[]> {
    await this.ensureConversationParticipant(conversationId, userId);
    const take = Math.min(Math.max(pagination?.limit ?? 50, 1), 200);
    const skip = Math.max(pagination?.offset ?? 0, 0);

    const messages = await this.prisma.chatMessage.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'desc' },
      include: {
        sender: {
          select: { id: true, name: true },
        },
      },
      take,
      skip,
    });

    return messages.reverse().map((message) => {
      const msg = message as any;
      return {
        id: msg.id,
        jobId: msg.conversationId, // Map to jobId for legacy frontend support if needed, or update frontend to use conversationId
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
    conversationId: number,
    userId: number,
    role: UserRole,
    dto: CreateMessageDto,
  ): Promise<ChatMessageDto> {
    if ((!dto.content || dto.content.trim() === '') && !dto.attachmentUrl) {
      throw new BadRequestException('Mesej atau lampiran diperlukan.');
    }

    const validatedContent: string = dto.content ?? '';

    await this.ensureConversationParticipant(conversationId, userId);
    const message = await this.prisma.$transaction(async (tx) => {
      const createdMessage = await tx.chatMessage.create({
        data: {
          content: validatedContent,
          type: dto.type ?? 'text',
          attachmentUrl: dto.attachmentUrl,
          conversationId: conversationId,
          senderId: userId,
        },
        include: {
          sender: {
            select: { id: true, name: true },
          },
        },
      });

      await tx.conversation.update({
        where: { id: conversationId },
        data: { updatedAt: new Date() },
      });

      return createdMessage;
    });

    const msg = message as any;
    return {
      id: msg.id,
      jobId: msg.conversationId,
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

  async getOrCreateConversation(
    userId: number,
    otherUserId: number,
  ): Promise<ChatThreadDto> {
    if (userId === otherUserId) {
      throw new BadRequestException('Cannot chat with yourself');
    }

    // Try to find existing conversation
    // Optimization: Find conversations of user, simplified
    const clientConvos = await this.prisma.conversation.findMany({
      where: { participants: { some: { id: userId } } },
      include: {
        participants: true,
        messages: { take: 1, orderBy: { createdAt: 'desc' } },
      },
    });

    let conversation = clientConvos.find((c) =>
      c.participants.some((p) => p.id === otherUserId),
    );

    if (!conversation) {
      conversation = await this.prisma.conversation.create({
        data: {
          participants: {
            connect: [{ id: userId }, { id: otherUserId }],
          },
        },
        include: { participants: true, messages: { take: 1 } },
      });
    }

    const otherParticipant = conversation.participants.find(
      (p) => p.id !== userId,
    );
    return {
      id: conversation.id,
      jobTitle: 'Conversation',
      participantName: otherParticipant?.name || 'Unknown',
      participantId: otherParticipant?.id || 0,
      participantAvatarUrl: otherParticipant?.avatarUrl || null,
      lastMessage: conversation.messages[0]?.content ?? null,
      lastAt: conversation.updatedAt,
      jobStatus: 'ACTIVE' as any,
      unreadCount: 0,
    };
  }

  private async ensureConversationParticipant(
    conversationId: number,
    userId: number,
  ) {
    const convo = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { participants: { select: { id: true } } },
    });

    if (!convo) {
      throw new NotFoundException('Conversation not found');
    }

    const isParticipant = convo.participants.some((p) => p.id === userId);
    if (!isParticipant) {
      throw new ForbiddenException('You are not part of this conversation');
    }
  }

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
    }); // No include needed

    if (!message) {
      throw new NotFoundException('Message not found');
    }

    if (message.senderId === userId) {
      return message;
    }

    return this.prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        deliveredAt: new Date(),
      } as any,
    });
  }

  async markMessageRead(messageId: number, userId: number) {
    const message = await this.prisma.chatMessage.findUnique({
      where: { id: messageId },
    });

    if (!message) {
      throw new NotFoundException('Message not found');
    }

    if (message.senderId === userId) {
      return message;
    }

    const msg = message as any;
    return this.prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        readAt: new Date(),
        deliveredAt: msg.deliveredAt || new Date(),
      } as any,
    });
  }

  async markChatRead(conversationId: number, userId: number) {
    const result = await this.prisma.$executeRaw`
      UPDATE "ChatMessage"
      SET "readAt" = NOW()
      WHERE "conversationId" = ${conversationId}
        AND "senderId" != ${userId}
        AND "readAt" IS NULL
    `;

    return { count: result };
  }
}
