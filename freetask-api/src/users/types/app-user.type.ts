import { UserRole } from '@prisma/client';

export type AppUser = {
  id: number;
  createdAt: Date;
  updatedAt: Date;
  email: string;
  name: string;
  role: UserRole;
  avatarUrl: string | null;
  bio: string | null;
  skills: string[] | null;
  rate: number | null;
  phoneNumber: string | null;
  location: string | null;
  rating?: number | null;
  reviewCount?: number | null;
};
