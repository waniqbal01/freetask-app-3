export class ChatMessageDto {
  id: number;
  jobId: number;
  senderId: number;
  senderName: string;
  content: string;
  type: string;
  attachmentUrl: string | null;
  createdAt: Date;
}
