export class ChatThreadDto {
  id: number;
  jobTitle: string;
  participantName: string;
  lastMessage?: string | null;
  lastAt?: Date | null;
  jobStatus: string;
}
