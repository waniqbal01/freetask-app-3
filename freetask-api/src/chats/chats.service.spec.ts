import { NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { ChatsService } from './chats.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

describe('ChatsService', () => {
  let prisma: any;
  let notifications: any;
  let service: ChatsService;

  beforeEach(() => {
    prisma = {
      conversation: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
      },
      chatMessage: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
        count: jest.fn(),
        update: jest.fn(),
      },
      user: {
        update: jest.fn(),
        findUnique: jest.fn(),
      },
      userBlock: {
        findMany: jest.fn(),
        findFirst: jest.fn(),
      },
      $transaction: jest.fn().mockImplementation(cb => cb(prisma)),
      $executeRaw: jest.fn().mockResolvedValue(1),
    };

    notifications = {
      sendNotification: jest.fn(),
    };

    service = new ChatsService(
      prisma as unknown as PrismaService,
      notifications as unknown as NotificationsService,
    );
  });

  const baseConversation = {
    id: 1,
    updatedAt: new Date('2024-01-01T00:00:00Z'),
    participants: [{ id: 10, name: 'User 10' }, { id: 20, name: 'User 20' }],
    messages: [],
    _count: { messages: 0 },
  };

  it('throws when user is not part of the conversation', async () => {
    prisma.conversation.findUnique.mockResolvedValue(null);

    await expect(
      service.postMessage(baseConversation.id, 99, 'CLIENT' as any, {
        content: 'Hello',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    prisma.conversation.findUnique.mockResolvedValue({ participants: [{ id: 10 }] });
    await expect(
      service.postMessage(baseConversation.id, 99, 'CLIENT' as any, {
        content: 'Hello',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('updates conversation timestamps when posting a message', async () => {
    prisma.conversation.findUnique.mockResolvedValue(baseConversation);
    prisma.userBlock.findFirst.mockResolvedValue(null);
    prisma.chatMessage.create.mockResolvedValue({
      id: 1,
      conversationId: baseConversation.id,
      senderId: 10,
      content: 'Hi',
      createdAt: new Date('2024-01-02T00:00:00Z'),
      sender: { id: 10, name: 'User 10', role: 'CLIENT' },
    });
    prisma.chatMessage.count.mockResolvedValue(0);

    await service.postMessage(baseConversation.id, 10, 'CLIENT' as any, {
      content: 'Hi',
    });

    expect(prisma.conversation.update).toHaveBeenCalledWith({
      where: { id: baseConversation.id },
      data: { updatedAt: expect.any(Date) },
    });
  });

  it('returns threads ordered by latest conversation update', async () => {
    const newerConversation = {
      ...baseConversation,
      id: 2,
      updatedAt: new Date('2024-01-03T00:00:00Z'),
      messages: [
        { content: 'Latest', createdAt: new Date('2024-01-03T00:00:00Z') },
      ],
      _count: { messages: 0 },
    };

    prisma.conversation.findMany.mockResolvedValue([newerConversation, baseConversation]);
    prisma.userBlock.findMany.mockResolvedValue([]);

    const threads = await service.listThreads(10, 'CLIENT' as any);
    expect(threads.map((t) => t.id)).toEqual([2, 1]);
    expect(threads[0].lastMessage).toBe('Latest');
  });

  it('paginates messages from newest chunk while returning ascending order', async () => {
    const recent = new Date('2024-01-05T00:00:00Z');
    const older = new Date('2024-01-04T00:00:00Z');
    prisma.conversation.findUnique.mockResolvedValue(baseConversation);
    prisma.chatMessage.findMany.mockResolvedValue([
      {
        id: 3,
        conversationId: baseConversation.id,
        senderId: 10,
        content: 'Latest',
        createdAt: recent,
        sender: { id: 10, name: 'User 10' },
      },
      {
        id: 2,
        conversationId: baseConversation.id,
        senderId: 20,
        content: 'Older',
        createdAt: older,
        sender: { id: 20, name: 'User 20' },
      },
    ]);

    const result = await service.listMessages(
      baseConversation.id,
      10,
      'CLIENT' as any,
      { limit: 2, offset: 1 },
    );

    expect(prisma.chatMessage.findMany).toHaveBeenCalledWith({
      where: { conversationId: baseConversation.id },
      orderBy: { createdAt: 'desc' },
      include: { sender: { select: { id: true, name: true } } },
      take: 2,
      skip: 1,
    });
    expect(result.map((message) => message.id)).toEqual([2, 3]);
  });

  it('blocks freelancer-to-freelancer conversations', async () => {
    prisma.user.findUnique
      .mockResolvedValueOnce({ id: 10, role: 'FREELANCER' })
      .mockResolvedValueOnce({ id: 20, role: 'FREELANCER' });

    await expect(
      service.getOrCreateConversation(10, 20),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('allows a client to start a conversation with a freelancer', async () => {
    prisma.user.findUnique
      .mockResolvedValueOnce({ id: 10, role: 'CLIENT' })
      .mockResolvedValueOnce({ id: 20, role: 'FREELANCER' });
    prisma.conversation.findFirst.mockResolvedValue(null);
    prisma.conversation.create.mockResolvedValue({
      id: 1,
      updatedAt: new Date(),
      participants: [
        { id: 10, name: 'Client', avatarUrl: null, isOnline: false, lastSeen: null },
        { id: 20, name: 'Freelancer', avatarUrl: null, isOnline: false, lastSeen: null },
      ],
      messages: [],
    });
    prisma.userBlock.findFirst.mockResolvedValue(null);

    const result = await service.getOrCreateConversation(10, 20);
    expect(result.id).toBe(1);
  });
});
