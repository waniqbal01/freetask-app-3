import { ServicesService } from './services.service';
import { PrismaService } from '../prisma/prisma.service';

describe('ServicesService', () => {
  let service: ServicesService;
  let prisma: Pick<PrismaService, 'service'>;

  beforeEach(() => {
    prisma = {
      service: {
        findMany: jest.fn(),
      },
    } as unknown as PrismaService;

    service = new ServicesService(prisma as PrismaService);
  });

  it('returns distinct sorted categories from services', async () => {
    (prisma.service.findMany as jest.Mock).mockResolvedValue([
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
});
