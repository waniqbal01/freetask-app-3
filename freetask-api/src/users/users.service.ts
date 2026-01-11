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

  async getPublicProfile(id: number) {
    const user = await this.ensureUserExists(id);
    // Reuse toAppUser or map manually if we need to hide more fields
    // For now toAppUser seems safe (excludes password)
    // We might want to include services later
    const publicData = toAppUser(user);
    
    // Fetch user's services to show on profile
    const services = await this.prisma.service.findMany({
      where: { freelancerId: id },
      select: {
          id: true,
          title: true,
          price: true,
          thumbnailUrl: true,
          category: true,
      }
    });

    return {
        ...publicData,
        services,
    };
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
}
