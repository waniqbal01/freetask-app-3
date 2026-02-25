import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { toAppUser } from './user.mapper';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) { }

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

    // Fetch user's services to show on profile (only approved)
    const services = await this.prisma.service.findMany({
      where: {
        freelancerId: id,
        approvalStatus: 'APPROVED', // Only show approved services
      },
      select: {
        id: true,
        title: true,
        price: true,
        thumbnailUrl: true,
        category: true,
      },
    });

    const aggregate = await this.prisma.review.aggregate({
      where: { revieweeId: id },
      _avg: { rating: true },
      _count: { id: true },
    });

    return {
      ...publicData,
      services,
      rating: aggregate._avg.rating ?? 0,
      reviewCount: aggregate._count.id ?? 0,
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
        phoneNumber: dto.phoneNumber,
        location: dto.location,
        state: dto.state,
        district: dto.district,
        latitude: dto.latitude,
        longitude: dto.longitude,
        coverageRadius: dto.coverageRadius,
        acceptsOutstation: dto.acceptsOutstation,
        isAvailable: dto.isAvailable,
        bankCode: dto.bankCode,
        bankAccount: dto.bankAccount,
        bankHolderName: dto.bankHolderName,
      },
    });

    return toAppUser(user);
  }

  // Admin: Get all users with bank details but NOT verified
  async findPendingBankVerifications() {
    const users = await this.prisma.user.findMany({
      where: {
        bankCode: { not: null },
        bankAccount: { not: null },
        bankVerified: false,
      },
      select: {
        id: true,
        name: true,
        email: true,
        bankCode: true,
        bankAccount: true,
        bankHolderName: true,
        updatedAt: true,
      },
      orderBy: { updatedAt: 'desc' },
    });
    return users;
  }

  // Admin: Approve bank details
  async verifyBankDetails(id: number) {
    const user = await this.prisma.user.update({
      where: { id },
      data: { bankVerified: true },
    });
    return toAppUser(user);
  }
}
