export class ChatMessageDto {
  id: number;
  jobId: number;
  senderId: number;
  senderName: string;
  content: string;
  createdAt: Date;
}
