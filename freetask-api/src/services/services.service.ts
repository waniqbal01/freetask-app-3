import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateServiceDto } from './dto/create-service.dto';
import { UpdateServiceDto } from './dto/update-service.dto';

@Injectable()
export class ServicesService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: number, role: UserRole, dto: CreateServiceDto) {
    if (role !== UserRole.FREELANCER) {
      throw new ForbiddenException('Only freelancers can create services');
    }

    const parsedPrice = Number(dto.price);
    if (!Number.isFinite(parsedPrice)) {
      throw new BadRequestException('price must be a valid number');
    }

    const created = await this.prisma.service.create({
      data: {
        title: dto.title,
        description: dto.description,
        price: new Prisma.Decimal(parsedPrice.toFixed(2)),
        category: dto.category,
        freelancerId: userId,
      },
      include: {
        freelancer: {
          select: { id: true, name: true, email: true },
        },
      },
    });

    return this.serializeService(created);
  }

  async findAll(q?: string, category?: string) {
    const services = await this.prisma.service.findMany({
      where: {
        ...(q
          ? {
              OR: [
                { title: { contains: q, mode: 'insensitive' } },
                { description: { contains: q, mode: 'insensitive' } },
              ],
            }
          : {}),
        ...(category ? { category } : {}),
      },
      include: {
        freelancer: {
          select: { id: true, name: true },
        },
      },
    });
    return services.map((service) => this.serializeService(service));
  }

  async findOne(id: number) {
    const service = await this.prisma.service.findUnique({
      where: { id },
      include: {
        freelancer: {
          select: { id: true, name: true, email: true },
        },
      },
    });
    if (!service) {
      throw new NotFoundException('Service not found');
    }
    return this.serializeService(service);
  }

  async update(id: number, userId: number, dto: UpdateServiceDto) {
    await this.ensureOwner(id, userId);
    const { price, ...rest } = dto;
    const data: Prisma.ServiceUpdateInput = { ...rest };

    if (price !== undefined) {
      const parsed = Number(price);
      if (!Number.isFinite(parsed)) {
        throw new BadRequestException('price must be a valid number');
      }
      data.price = new Prisma.Decimal(parsed.toFixed(2));
    }

    const updated = await this.prisma.service.update({
      where: { id },
      data,
    });

    return this.serializeService(updated);
  }

  async remove(id: number, userId: number) {
    await this.ensureOwner(id, userId);
    await this.prisma.service.delete({ where: { id } });
    return { success: true };
  }

  async categories(): Promise<string[]> {
    const results = await this.prisma.service.findMany({
      distinct: ['category'],
      select: { category: true },
      orderBy: { category: 'asc' },
    });

    return results
      .map((item) => item.category)
      .filter((category): category is string => Boolean(category));
  }

  private async ensureOwner(serviceId: number, userId: number) {
    const service = await this.prisma.service.findUnique({
      where: { id: serviceId },
      select: { freelancerId: true },
    });
    if (!service) {
      throw new NotFoundException('Service not found');
    }
    if (service.freelancerId !== userId) {
      throw new ForbiddenException('You do not own this service');
    }
  }

  private serializeService<T extends { price: Prisma.Decimal | number | string }>(
    service: T,
  ) {
    const price = service.price;
    const normalizedPrice =
      price instanceof Prisma.Decimal
        ? price.toNumber()
        : typeof price === 'string'
          ? Number(price)
          : Number(price);

    return {
      ...service,
      price: Number.isFinite(normalizedPrice) ? normalizedPrice : 0,
    };
  }
}
