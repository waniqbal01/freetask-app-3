import { JobStatus } from '@prisma/client';

export class ChatMessagePreviewDto {
  id: number;
  content: string;
  senderId: number;
  senderName: string;
  createdAt: Date;
}

export class ChatThreadDto {
  id: number;
  jobId: number;
  jobTitle: string;
  participantName: string;
  clientName: string;
  freelancerName: string;
  status: JobStatus;
  lastMessage?: ChatMessagePreviewDto;
}
