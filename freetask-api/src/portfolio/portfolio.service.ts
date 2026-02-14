import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePortfolioItemDto } from './dto/create-portfolio-item.dto';
import { UpdatePortfolioItemDto } from './dto/update-portfolio-item.dto';

@Injectable()
export class PortfolioService {
  constructor(private prisma: PrismaService) {}

  create(userId: number, createDto: CreatePortfolioItemDto) {
    return this.prisma.portfolioItem.create({
      data: {
        ...createDto,
        freelancerId: userId,
      },
    });
  }

  findAll(userId: number) {
    return this.prisma.portfolioItem.findMany({
      where: { freelancerId: userId },
    });
  }

  findOne(id: number) {
    return this.prisma.portfolioItem.findUnique({ where: { id } });
  }

  update(id: number, updateDto: UpdatePortfolioItemDto) {
    return this.prisma.portfolioItem.update({
      where: { id },
      data: updateDto,
    });
  }

  remove(id: number) {
    return this.prisma.portfolioItem.delete({ where: { id } });
  }
}
