import { User } from '@prisma/client';
import { AppUser } from './types/app-user.type';

export const toAppUser = (user: User): AppUser => {
  const skills = Array.isArray(user.skills)
    ? user.skills
      .map((skill) =>
        skill !== null && skill !== undefined ? skill.toString() : '',
      )
      .filter((skill) => skill.length > 0)
    : user.skills
      ? [user.skills.toString()]
      : null;

  return {
    id: user.id,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
    email: user.email,
    name: user.name,
    role: user.role,
    avatarUrl: user.avatarUrl ?? null,
    bio: user.bio ?? null,
    skills,
    rate:
      user.rate !== null && user.rate !== undefined ? Number(user.rate) : null,
    phoneNumber: user.phoneNumber,
    location: user.location,
    state: user.state,
    district: user.district,
    latitude: user.latitude,
    longitude: user.longitude,
    coverageRadius: user.coverageRadius,
    acceptsOutstation: user.acceptsOutstation,
    isAvailable: user.isAvailable,
    bankCode: user.bankCode,
    bankAccount: user.bankAccount,
    bankHolderName: user.bankHolderName,
    bankVerified: user.bankVerified,
    level: user.level,
    totalCompletedJobs: user.totalCompletedJobs,
    totalReviews: user.totalReviews,
    replyRate: user.replyRate ? Number(user.replyRate) : null,
    rating: user.totalReviews > 0 ? Number(user.totalRatingScore) / user.totalReviews : 0,
    reviewCount: user.totalReviews,
  };
};
