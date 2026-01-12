import { User } from '@prisma/client';
import { AppUser } from './types/app-user.type';

export const toAppUser = (user: User): AppUser => {
  const skills = Array.isArray(user.skills)
    ? user.skills
      .map((skill) => (skill !== null && skill !== undefined ? skill.toString() : ''))
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
    rate: user.rate !== null && user.rate !== undefined ? Number(user.rate) : null,
    phoneNumber: user.phoneNumber,
    location: user.location,
  };
};
