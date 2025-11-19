import { ForbiddenException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { ServicesService } from './services.service';
import { PrismaService } from '../prisma/prisma.service';

describe('ServicesService', () => {
  let service: ServicesService;
  let prisma: {
    service: {
      findMany: jest.Mock;
      create: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
  };

  beforeEach(() => {
    prisma = {
      service: {
        findMany: jest.fn(),
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
    };

    service = new ServicesService(prisma as unknown as PrismaService);
  });

  it('allows freelancers to create services with pricing info', async () => {
    const dto = {
      title: 'Logo Design',
      description: 'Modern minimal logo',
      price: 200,
      category: 'Design',
    };
    const created = { id: 1, ...dto, freelancerId: 3 };
    prisma.service.create.mockResolvedValue(created);

    const result = await service.create(3, UserRole.FREELANCER, dto);

    expect(prisma.service.create).toHaveBeenCalled();
    expect(result).toEqual(created);
  });

  it('blocks non-freelancers from creating services', async () => {
    await expect(
      service.create(1, UserRole.CLIENT, {
        title: 'x',
        description: 'y',
        price: 10,
        category: 'Design',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.service.create).not.toHaveBeenCalled();
  });

  it('returns distinct sorted categories from services', async () => {
    prisma.service.findMany.mockResolvedValue([
      { category: 'Design' },
      { category: 'Cleaning' },
    ]);

    const categories = await service.categories();

    expect(prisma.service.findMany).toHaveBeenCalledWith({
      distinct: ['category'],
      select: { category: true },
      orderBy: { category: 'asc' },
    });
    expect(categories).toEqual(['Design', 'Cleaning']);
  });

  it('filters services for owner via findMine', async () => {
    prisma.service.findMany.mockResolvedValue([{ id: 1, freelancerId: 7 }]);
    const result = await service.findMine(7);
    expect(prisma.service.findMany).toHaveBeenCalledWith({
      where: { freelancerId: 7 },
      orderBy: { createdAt: 'desc' },
      include: { freelancer: { select: { id: true, name: true } } },
    });
    expect(result).toHaveLength(1);
  });
});
