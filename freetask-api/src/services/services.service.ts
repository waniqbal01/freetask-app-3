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

  findAll() {
    return this.prisma.service.findMany({
      include: {
        freelancer: {
          select: { id: true, name: true },
        },
      },
    });
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
    return service;
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
}
