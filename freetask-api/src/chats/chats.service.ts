import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMessageDto } from './dto/create-message.dto';
import { ChatMessagePreviewDto, ChatThreadDto } from './dto/chat-thread.dto';

@Injectable()
export class ChatsService {
  constructor(private readonly prisma: PrismaService) {}

  async listThreads(userId: number): Promise<ChatThreadDto[]> {
    const jobs = await this.prisma.job.findMany({
      where: {
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
          take: 1,
          orderBy: { createdAt: 'desc' },
          include: {
            sender: { select: { id: true, name: true } },
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return jobs.map((job) => {
      const lastMessageEntity = job.messages[0];
      const lastMessage: ChatMessagePreviewDto | undefined = lastMessageEntity
        ? {
            id: lastMessageEntity.id,
            content: lastMessageEntity.content,
            senderId: lastMessageEntity.senderId,
            senderName: lastMessageEntity.sender.name,
            createdAt: lastMessageEntity.createdAt,
          }
        : undefined;

      const participantName = job.clientId === userId ? job.freelancer.name : job.client.name;

      return {
        id: job.id,
        jobId: job.id,
        jobTitle: job.title,
        participantName,
        clientName: job.client.name,
        freelancerName: job.freelancer.name,
        status: job.status,
        lastMessage,
      } satisfies ChatThreadDto;
    });
  }

  async listMessages(jobId: number, userId: number) {
    await this.ensureJobParticipant(jobId, userId);
    return this.prisma.chatMessage.findMany({
      where: { jobId },
      orderBy: { createdAt: 'asc' },
      include: {
        sender: {
          select: { id: true, name: true },
        },
      },
    });
  }

  async postMessage(jobId: number, userId: number, dto: CreateMessageDto) {
    await this.ensureJobParticipant(jobId, userId);
    return this.prisma.chatMessage.create({
      data: {
        content: dto.content,
        jobId,
        senderId: userId,
      },
      include: {
        sender: {
          select: { id: true, name: true },
        },
      },
    });
  }

  private async ensureJobParticipant(jobId: number, userId: number) {
    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) {
      throw new NotFoundException('Job not found');
    }
    if (job.clientId !== userId && job.freelancerId !== userId) {
      throw new ForbiddenException('You are not part of this job');
    }
  }
}
