import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
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

    return this.prisma.service.create({
      data: {
        title: dto.title,
        description: dto.description,
        price: new Prisma.Decimal(dto.price),
        category: dto.category,
        freelancerId: userId,
      },
      include: {
        freelancer: {
          select: { id: true, name: true, email: true },
        },
      },
    });
  }

  findAll(q?: string, category?: string, freelancerId?: number) {
    return this.prisma.service
      .findMany({
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
          ...(freelancerId ? { freelancerId } : {}),
        },
        include: {
          freelancer: {
            select: { id: true, name: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      })
      .then((services) => this.attachRatingSummary(services));
  }

  findMine(userId: number) {
    return this.prisma.service
      .findMany({
        where: { freelancerId: userId },
        orderBy: { createdAt: 'desc' },
        include: {
          freelancer: {
            select: { id: true, name: true },
          },
        },
      })
      .then((services) => this.attachRatingSummary(services));
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

    const aggregate = await this.prisma.review.aggregate({
      where: { job: { serviceId: id } },
      _avg: { rating: true },
      _count: { _all: true },
    });

    return {
      ...service,
      averageRating: aggregate._avg.rating ?? 0,
      reviewCount: aggregate._count._all,
    };
  }

  async update(id: number, userId: number, dto: UpdateServiceDto) {
    await this.ensureOwner(id, userId);
    const { price, ...rest } = dto;
    return this.prisma.service.update({
      where: { id },
      data: {
        ...rest,
        price: price !== undefined ? new Prisma.Decimal(price) : undefined,
      },
    });
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

  private async attachRatingSummary<T extends { id: number }>(services: T[]) {
    const serviceIds = services.map((service) => service.id);
    if (serviceIds.length === 0) {
      return services.map((service) => ({
        ...service,
        averageRating: 0,
        reviewCount: 0,
      }));
    }

    const reviews = await this.prisma.review.findMany({
      where: { job: { serviceId: { in: serviceIds } } },
      select: { rating: true, job: { select: { serviceId: true } } },
    });

    const summary = new Map<number, { total: number; count: number }>();
    for (const review of reviews) {
      const serviceId = review.job.serviceId;
      const current = summary.get(serviceId) ?? { total: 0, count: 0 };
      summary.set(serviceId, {
        total: current.total + review.rating,
        count: current.count + 1,
      });
    }

    return services.map((service) => {
      const data = summary.get(service.id);
      return {
        ...service,
        averageRating: data ? data.total / data.count : 0,
        reviewCount: data?.count ?? 0,
      };
    });
  }
}
