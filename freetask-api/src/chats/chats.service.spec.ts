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
  };

  let prisma: jest.Mocked<Pick<PrismaService, 'job' | 'chatMessage' | '$transaction'>>;
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
    } as unknown as jest.Mocked<Pick<PrismaService, 'job' | 'chatMessage' | '$transaction'>>;

    prisma.$transaction.mockImplementation(async (cb) => {
      return cb(prisma as unknown as PrismaService);
    });

    service = new ChatsService(prisma as unknown as PrismaService);
  });

  it('throws when user is not part of the job', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(null);

    await expect(service.postMessage(baseJob.id, 99, { content: 'Hello' })).rejects.toBeInstanceOf(NotFoundException);
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

    await service.postMessage(baseJob.id, baseJob.clientId, { content: 'Hi' });

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
    };

    (prisma.job.findMany as jest.Mock)
      .mockResolvedValueOnce([newerJob, baseJob])
      .mockResolvedValueOnce([
        {
          ...baseJob,
          updatedAt: new Date('2024-01-04T00:00:00Z'),
        },
        newerJob,
      ]);
    (prisma.job.findUnique as jest.Mock).mockResolvedValue({ ...baseJob, updatedAt: new Date('2024-01-02T00:00:00Z') });
    (prisma.chatMessage.create as jest.Mock).mockResolvedValue({
      id: 99,
      jobId: baseJob.id,
      senderId: baseJob.clientId,
      content: 'Ping',
      createdAt: new Date('2024-01-02T01:00:00Z'),
      sender: { id: baseJob.clientId, name: 'Client A' },
    });

    const initialOrder = await service.listThreads(baseJob.clientId);
    expect(initialOrder.map((thread) => thread.id)).toEqual([2, 1]);

    await service.postMessage(baseJob.id, baseJob.clientId, { content: 'Ping' });

    const reordered = await service.listThreads(baseJob.clientId);
    expect(reordered.map((thread) => thread.id)).toEqual([1, 2]);
  });

  it('keeps order stable when no updates occur', async () => {
    (prisma.job.findMany as jest.Mock).mockResolvedValue([baseJob]);

    const threads = await service.listThreads(baseJob.clientId);

    expect(prisma.job.findMany).toHaveBeenCalledWith({
      where: { OR: [{ clientId: baseJob.clientId }, { freelancerId: baseJob.clientId }] },
      include: {
        client: { select: { id: true, name: true } },
        freelancer: { select: { id: true, name: true } },
      },
      orderBy: { updatedAt: 'desc' },
    });
    expect(threads).toHaveLength(1);
  });
});
