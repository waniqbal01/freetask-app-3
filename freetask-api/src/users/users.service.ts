import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { toAppUser } from './user.mapper';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  create(data: Prisma.UserCreateInput) {
    return this.prisma.user.create({ data });
  }

  findByEmail(email: string) {
    return this.prisma.user.findUnique({ where: { email } });
  }

  findById(id: number) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async ensureUserExists(id: number): Promise<User> {
    const user = await this.findById(id);
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  async getProfile(id: number) {
    const user = await this.ensureUserExists(id);
    return toAppUser(user);
  }

  async updateProfile(id: number, dto: UpdateUserDto) {
    const avatarUrl = dto.avatarUrl ?? dto.avatar;

    const user = await this.prisma.user.update({
      where: { id },
      data: {
        name: dto.name,
        avatarUrl,
        bio: dto.bio,
        skills: dto.skills,
        rate: dto.rate,
      },
    });

    return toAppUser(user);
  }

  updateDeviceToken(userId: number, deviceToken: string | null) {
    const sanitized = deviceToken?.trim();
    return this.prisma.user.update({
      where: { id: userId },
      data: { deviceToken: sanitized?.length ? sanitized : null },
      select: { id: true, deviceToken: true },
    });
  }
}
