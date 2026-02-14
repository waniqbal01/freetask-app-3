import { NotFoundException } from '@nestjs/common';
import { ChatsService } from './chats.service';
import { PrismaService } from '../prisma/prisma.service';

describe('ChatsService', () => {
  const baseJob = {
    id: 1,
    title: 'Alpha',
    updatedAt: new Date('2024-01-01T00:00:00Z'),
    clientId: 10,
    freelancerId: 20,
    client: { id: 10, name: 'Client A' },
    freelancer: { id: 20, name: 'Freelancer A' },
    messages: [],
  };

  let prisma: jest.Mocked<
    Pick<PrismaService, 'job' | 'chatMessage' | '$transaction'>
  >;
  let service: ChatsService;

  beforeEach(() => {
    prisma = {
      job: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      chatMessage: {
        findMany: jest.fn(),
        create: jest.fn(),
      },
      $transaction: jest.fn(),
    } as unknown as jest.Mocked<
      Pick<PrismaService, 'job' | 'chatMessage' | '$transaction'>
    >;

    prisma.$transaction.mockImplementation(async (cb) => {
      return cb(prisma as unknown as PrismaService);
    });

    service = new ChatsService(prisma as unknown as PrismaService);
  });

  it('throws when user is not part of the job', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(null);

    await expect(
      service.postMessage(baseJob.id, 99, 'CLIENT' as any, {
        content: 'Hello',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('updates job timestamps when posting a message', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);
    (prisma.chatMessage.create as jest.Mock).mockResolvedValue({
      id: 1,
      jobId: baseJob.id,
      senderId: baseJob.clientId,
      content: 'Hi',
      createdAt: new Date('2024-01-02T00:00:00Z'),
      sender: { id: baseJob.clientId, name: 'Client A' },
    });

    await service.postMessage(baseJob.id, baseJob.clientId, 'CLIENT' as any, {
      content: 'Hi',
    });

    expect(prisma.job.update).toHaveBeenCalledWith({
      where: { id: baseJob.id },
      data: { updatedAt: expect.any(Date) },
    });
  });

  it('returns threads ordered by latest job update', async () => {
    const newerJob = {
      ...baseJob,
      id: 2,
      title: 'Beta',
      updatedAt: new Date('2024-01-03T00:00:00Z'),
      client: { id: 20, name: 'Client B' },
      freelancer: { id: 10, name: 'Freelancer B' },
      messages: [
        { content: 'Latest', createdAt: new Date('2024-01-03T00:00:00Z') },
      ],
    };

    (prisma.job.findMany as jest.Mock)
      .mockResolvedValueOnce([newerJob, baseJob])
      .mockResolvedValueOnce([
        {
          ...baseJob,
          updatedAt: new Date('2024-01-04T00:00:00Z'),
          messages: [
            { content: 'Ping', createdAt: new Date('2024-01-04T00:00:00Z') },
          ],
        },
        newerJob,
      ]);
    (prisma.job.findUnique as jest.Mock).mockResolvedValue({
      ...baseJob,
      updatedAt: new Date('2024-01-02T00:00:00Z'),
    });
    (prisma.chatMessage.create as jest.Mock).mockResolvedValue({
      id: 99,
      jobId: baseJob.id,
      senderId: baseJob.clientId,
      content: 'Ping',
      createdAt: new Date('2024-01-02T01:00:00Z'),
      sender: { id: baseJob.clientId, name: 'Client A' },
    });

    const initialOrder = await service.listThreads(
      baseJob.clientId,
      'CLIENT' as any,
    );
    expect(initialOrder.map((thread) => thread.id)).toEqual([2, 1]);
    expect(initialOrder[0].lastMessage).toBe('Latest');
    expect(initialOrder[0].lastAt?.toISOString()).toBe(
      '2024-01-03T00:00:00.000Z',
    );

    await service.postMessage(baseJob.id, baseJob.clientId, 'CLIENT' as any, {
      content: 'Ping',
    });

    const reordered = await service.listThreads(
      baseJob.clientId,
      'CLIENT' as any,
    );
    expect(reordered.map((thread) => thread.id)).toEqual([1, 2]);
    expect(reordered[0].lastMessage).toBe('Ping');
  });

  it('keeps order stable when no updates occur', async () => {
    (prisma.job.findMany as jest.Mock).mockResolvedValue([baseJob]);

    const threads = await service.listThreads(
      baseJob.clientId,
      'CLIENT' as any,
    );

    expect(prisma.job.findMany).toHaveBeenCalledWith({
      where: {
        OR: [
          { clientId: baseJob.clientId },
          { freelancerId: baseJob.clientId },
        ],
      },
      include: {
        client: { select: { id: true, name: true } },
        freelancer: { select: { id: true, name: true } },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { content: true, createdAt: true },
        },
      },
      orderBy: { updatedAt: 'desc' },
      take: 20,
      skip: 0,
    });
    expect(threads).toHaveLength(1);
  });

  it('paginates messages from newest chunk while returning ascending order', async () => {
    const recent = new Date('2024-01-05T00:00:00Z');
    const older = new Date('2024-01-04T00:00:00Z');
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);
    (prisma.chatMessage.findMany as jest.Mock).mockResolvedValue([
      {
        id: 3,
        jobId: baseJob.id,
        senderId: baseJob.clientId,
        content: 'Latest',
        createdAt: recent,
        sender: { id: baseJob.clientId, name: 'Client A' },
      },
      {
        id: 2,
        jobId: baseJob.id,
        senderId: baseJob.freelancerId,
        content: 'Older',
        createdAt: older,
        sender: { id: baseJob.freelancerId, name: 'Freelancer A' },
      },
    ]);

    const result = await service.listMessages(
      baseJob.id,
      baseJob.clientId,
      'CLIENT' as any,
      {
        limit: 2,
        offset: 1,
      },
    );

    expect(prisma.chatMessage.findMany).toHaveBeenCalledWith({
      where: { jobId: baseJob.id },
      orderBy: { createdAt: 'desc' },
      include: { sender: { select: { id: true, name: true } } },
      take: 2,
      skip: 1,
    });
    expect(result.map((message) => message.id)).toEqual([2, 3]);
    expect(result[0].createdAt < result[1].createdAt).toBe(true);
  });
});
