import { JobStatus } from '@prisma/client';

export interface ChatThreadDto {
  id: number;
  jobTitle: string;
  participantName: string;
  participantId: number;
  participantAvatarUrl: string | null;
  lastMessage: string | null;
  lastAt: Date;
  jobStatus: JobStatus;
  unreadCount: number;
  isBlocked?: boolean;
}
