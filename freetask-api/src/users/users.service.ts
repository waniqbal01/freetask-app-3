import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
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

  async getFreelancers(query: {
    q?: string;
    category?: string;
    state?: string;
    district?: string;
  }) {
    const andConditions: Prisma.UserWhereInput[] = [
      { role: 'FREELANCER' },
      { isAvailable: true },
    ];

    if (query.q) {
      const searchTerm = query.q;
      andConditions.push({
        OR: [
          { name: { contains: searchTerm, mode: 'insensitive' } },
          { bio: { contains: searchTerm, mode: 'insensitive' } },
          {
            services: {
              some: {
                OR: [
                  { title: { contains: searchTerm, mode: 'insensitive' } },
                  { category: { contains: searchTerm, mode: 'insensitive' } },
                ],
                approvalStatus: 'APPROVED',
                isActive: true,
              },
            },
          },
        ],
      });
    }

    if (query.category && query.category !== 'Semua') {
      andConditions.push({
        OR: [
          // Freelancer has an approved, active service in this category
          {
            services: {
              some: {
                category: query.category,
                approvalStatus: 'APPROVED',
                isActive: true,
              },
            },
          },
          // OR freelancer selected this category during signup (stored as JSONB array in skills/categories)
          {
            skills: {
              array_contains: [query.category],
            },
          },
        ],
      });
    }

    if (query.state) {
      andConditions.push({ state: query.state });
    }

    if (query.district) {
      andConditions.push({ district: query.district });
    }

    const freelancers = await this.prisma.user.findMany({
      where: {
        AND: andConditions,
      },
      select: {
        id: true,
        name: true,
        role: true,
        avatarUrl: true,
        bio: true,
        skills: true,
        rate: true,
        location: true,
        state: true,
        district: true,
        latitude: true,
        longitude: true,
        coverageRadius: true,
        acceptsOutstation: true,
        isAvailable: true,
        level: true,
        totalCompletedJobs: true,
        totalReviews: true,
        replyRate: true,
        services: {
          where: {
            approvalStatus: 'APPROVED',
            isActive: true,
          },
          select: {
            title: true,
            category: true,
          },
        },
        // We do sensitive exclusions manually or just rely on what we select
      },
    });

    // Add aggregate ratings for each freelancer
    const result = await Promise.all(
      freelancers.map(async (f) => {
        const aggregate = await this.prisma.review.aggregate({
          where: { revieweeId: f.id },
          _avg: { rating: true },
          _count: { id: true },
        });

        return {
          ...f,
          rating: aggregate._avg.rating ?? 0,
          reviewCount: aggregate._count.id ?? 0,
        };
      })
    );

    return result;
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

  async blockUser(blockerId: number, blockedId: number, reason?: string, isReported?: boolean) {
    if (blockerId === blockedId) {
      throw new BadRequestException('You cannot block yourself');
    }

    // Check if the blocked user exists
    await this.ensureUserExists(blockedId);

    // Check for active jobs between these two users
    const activeJobs = await this.prisma.job.findFirst({
      where: {
        OR: [
          { clientId: blockerId, freelancerId: blockedId },
          { clientId: blockedId, freelancerId: blockerId },
        ],
        status: {
          in: ['PENDING', 'AWAITING_PAYMENT', 'IN_PROGRESS', 'SUBMITTED', 'IN_REVIEW', 'IN_REVISION', 'DISPUTED'],
        },
      },
    });

    if (activeJobs) {
      throw new BadRequestException('Tidak boleh sekat pengguna yang mempunyai task/kerja aktif');
    }

    // Upsert or create block
    return this.prisma.userBlock.upsert({
      where: {
        blockerId_blockedId: { blockerId, blockedId },
      },
      update: {
        reason,
        isReported: isReported ?? false,
      },
      create: {
        blockerId,
        blockedId,
        reason,
        isReported: isReported ?? false,
      },
    });
  }
}
