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
          select: {
            content: true,
            createdAt: true,
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
      take,
      skip,
    });

    return jobs.map((job) => {
      const participantName = job.clientId === userId ? job.freelancer.name : job.client.name;

      return {
        id: job.id,
        jobTitle: job.title,
        participantName,
        lastMessage: job.messages[0]?.content ?? null,
        lastAt: job.messages[0]?.createdAt ?? job.updatedAt,
        jobStatus: job.status,
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
      .map(
        (message) =>
          ({
            id: message.id,
            jobId: message.jobId,
            senderId: message.sender.id,
            senderName: message.sender.name,
            content: message.content,
            type: message.type,
            attachmentUrl: message.attachmentUrl,
            createdAt: message.createdAt,
          }) satisfies ChatMessageDto,
      );
  }

  async postMessage(
    jobId: number,
    userId: number,
    role: UserRole,
    dto: CreateMessageDto,
  ): Promise<ChatMessageDto> {
    // Validate that content is provided
    if (!dto.content || dto.content.trim() === '') {
      throw new BadRequestException('Message content is required');
    }

    // TypeScript now knows content is non-null
    const validatedContent: string = dto.content;

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

    // TypeScript might not infer sender properly, so we'll be explicit
    return {
      id: message.id,
      jobId: message.jobId,
      senderId: message.sender.id,
      senderName: message.sender.name,
      content: message.content,
      type: message.type,
      attachmentUrl: message.attachmentUrl,
      createdAt: message.createdAt,
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
}
