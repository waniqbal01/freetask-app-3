export interface ChatThreadDto {
  id: number;
  conversationTitle: string;
  participantName: string;
  participantId: number;
  participantAvatarUrl: string | null;
  lastMessage: string | null;
  lastAt: Date;
  unreadCount: number;
  isBlocked?: boolean;
  isOnline?: boolean;
  lastSeen?: Date | null;
  isAvailable?: boolean;
}
