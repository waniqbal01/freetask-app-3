import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Job } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMessageDto } from './dto/create-message.dto';
import { ChatMessageDto } from './dto/chat-message.dto';
import { ChatThreadDto } from './dto/chat-thread.dto';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class ChatsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

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
      },
      orderBy: { updatedAt: 'desc' },
    });

    return jobs.map((job) => {
      const participantName = job.clientId === userId ? job.freelancer.name : job.client.name;

      return {
        id: job.id,
        jobTitle: job.title,
        participantName,
      } satisfies ChatThreadDto;
    });
  }

  async listMessages(jobId: number, userId: number): Promise<ChatMessageDto[]> {
    await this.ensureJobParticipant(jobId, userId);
    const messages = await this.prisma.chatMessage.findMany({
      where: { jobId },
      orderBy: { createdAt: 'asc' },
      include: {
        sender: {
          select: { id: true, name: true },
        },
      },
    });

    return messages.map(
      (message) =>
        ({
          id: message.id,
          sender: message.sender.name,
          text: message.content,
          timestamp: message.createdAt,
        }) satisfies ChatMessageDto,
    );
  }

  async postMessage(jobId: number, userId: number, dto: CreateMessageDto): Promise<ChatMessageDto> {
    const job = await this.ensureJobParticipant(jobId, userId);
    const message = await this.prisma.chatMessage.create({
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

    const payload = {
      id: message.id,
      sender: message.sender.name,
      text: message.content,
      timestamp: message.createdAt,
    } satisfies ChatMessageDto;

    const recipientId =
      job.clientId === userId ? job.freelancerId : job.clientId;
    await this.notificationsService.notifyUser(
      recipientId,
      'MESSAGE_RECEIVED',
      `Mesej baharu untuk ${job.title}`,
      dto.content,
      { jobId },
    );

    return payload;
  }

  async ensureJobParticipant(jobId: number, userId: number): Promise<Job> {
    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) {
      throw new NotFoundException('Job not found');
    }
    if (job.clientId !== userId && job.freelancerId !== userId) {
      throw new ForbiddenException('You are not part of this job');
    }
    return job;
  }
}
