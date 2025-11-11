import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMessageDto } from './dto/create-message.dto';

@Injectable()
export class ChatsService {
  constructor(private readonly prisma: PrismaService) {}

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
