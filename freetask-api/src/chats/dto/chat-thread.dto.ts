import { JobStatus } from '@prisma/client';

export interface ChatThreadDto {
  id: number;
  jobTitle: string;
  participantName: string;
  participantId: number;
  lastMessage: string | null;
  lastAt: Date;
  jobStatus: JobStatus;
  unreadCount: number;
}
