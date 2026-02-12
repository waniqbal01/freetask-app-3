import { MessageStatus } from '@prisma/client';

export class ChatMessageDto {
  id: number;
  jobId: number;
  senderId: number;
  senderName: string;
  content: string;
  type: string;
  attachmentUrl: string | null;
  createdAt: Date;
  status: MessageStatus;
  deliveredAt: Date | null;
  readAt: Date | null;
  replyToId: number | null;
}
