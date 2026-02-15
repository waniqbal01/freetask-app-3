import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger, UseGuards } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { WsJwtGuard } from './ws-jwt.guard';
import { ChatsService } from '../chats/chats.service';

interface AuthenticatedSocket extends Socket {
  userId: number;
  userName: string;
}

@WebSocketGateway({
  cors: {
    origin: process.env.FRONTEND_URL || '*',
    credentials: true,
  },
})
@UseGuards(WsJwtGuard)
export class ChatGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(ChatGateway.name);
  private userSockets = new Map<number, Set<string>>(); // userId -> Set of socketIds
  private socketUsers = new Map<string, number>(); // socketId -> userId
  private lastSeen = new Map<number, Date>(); // userId -> lastSeenTime

  constructor(
    private readonly chatsService: ChatsService,
    private readonly jwtService: JwtService,
  ) { }

  afterInit(server: Server) {
    this.logger.log('WebSocket Gateway initialized');
  }

  async handleConnection(client: AuthenticatedSocket) {
    try {
      // Manually verify token because Guard doesn't run for handleConnection
      const token = this.extractToken(client);

      if (!token) {
        this.logger.warn(`Connection rejected: No token provided`);
        client.disconnect();
        return;
      }

      try {
        const payload = this.jwtService.verify(token, {
          secret: process.env.JWT_SECRET,
        });

        // Attach user info to socket
        client.userId = payload.userId;
        client.userName = payload.name;

      } catch (e) {
        this.logger.warn(`Connection rejected: Invalid token - ${e.message}`);
        client.disconnect();
        return;
      }

      const userId = client.userId;
      if (!userId) {
        this.logger.warn(`Connection rejected: No userId in socket after auth`);
        client.disconnect();
        return;
      }

      this.logger.log(`Client connected: ${client.id}, User: ${userId}`);

      // Track user socket
      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, new Set());
      }
      this.userSockets.get(userId)!.add(client.id);
      this.socketUsers.set(client.id, userId);

      // Broadcast user online status
      this.server.emit('user_online', {
        userId,
        isOnline: true,
      });
    } catch (error) {
      this.logger.error(`Connection error: ${error.message}`);
      client.disconnect();
    }
  }

  async handleDisconnect(client: AuthenticatedSocket) {
    const userId = this.socketUsers.get(client.id);
    if (!userId) return;

    this.logger.log(`Client disconnected: ${client.id}, User: ${userId}`);

    // Remove socket tracking
    const userSocketSet = this.userSockets.get(userId);
    if (userSocketSet) {
      userSocketSet.delete(client.id);
      if (userSocketSet.size === 0) {
        this.userSockets.delete(userId);

        // User is fully offline now
        const lastSeenTime = new Date();
        this.lastSeen.set(userId, lastSeenTime);

        this.server.emit('user_offline', {
          userId,
          isOnline: false,
          lastSeen: lastSeenTime.toISOString(),
        });
      }
    }
    this.socketUsers.delete(client.id);
  }

  @SubscribeMessage('join_room')
  handleJoinRoom(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { conversationId: string },
  ) {
    const roomName = `conversation:${data.conversationId}`;
    client.join(roomName);
    this.logger.log(`User ${client.userId} joined room: ${roomName}`);
    return {
      event: 'room_joined',
      data: { conversationId: data.conversationId },
    };
  }

  @SubscribeMessage('leave_room')
  handleLeaveRoom(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { conversationId: string },
  ) {
    const roomName = `conversation:${data.conversationId}`;
    client.leave(roomName);
    this.logger.log(`User ${client.userId} left room: ${roomName}`);
    return {
      event: 'room_left',
      data: { conversationId: data.conversationId },
    };
  }

  @SubscribeMessage('typing_start')
  handleTypingStart(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { conversationId: string },
  ) {
    const roomName = `conversation:${data.conversationId}`;
    // Broadcast to everyone in room except sender
    client.to(roomName).emit('typing_start', {
      userId: client.userId,
      conversationId: data.conversationId,
    });
  }

  @SubscribeMessage('typing_stop')
  handleTypingStop(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { conversationId: string },
  ) {
    const roomName = `conversation:${data.conversationId}`;
    client.to(roomName).emit('typing_stop', {
      userId: client.userId,
      conversationId: data.conversationId,
    });
  }

  @SubscribeMessage('heartbeat')
  handleHeartbeat(@ConnectedSocket() client: AuthenticatedSocket) {
    // Keep connection alive
    return {
      event: 'heartbeat_ack',
      data: { timestamp: new Date().toISOString() },
    };
  }

  @SubscribeMessage('mark_delivered')
  async handleMarkDelivered(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { messageId: number; conversationId: string },
  ) {
    try {
      await this.chatsService.markMessageDelivered(
        data.messageId,
        client.userId,
      );

      // Notify message sender
      const message = await this.chatsService.getMessage(data.messageId);
      if (message) {
        this.emitToUser(message.senderId, 'message_delivered', {
          messageId: data.messageId,
          deliveredAt: new Date().toISOString(),
        });
      }
    } catch (error) {
      this.logger.error(`Failed to mark message delivered: ${error.message}`);
    }
  }

  @SubscribeMessage('mark_read')
  async handleMarkRead(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { messageId: number; conversationId: string },
  ) {
    try {
      await this.chatsService.markMessageRead(data.messageId, client.userId);

      // Notify message sender
      const message = await this.chatsService.getMessage(data.messageId);
      if (message) {
        this.emitToUser(message.senderId, 'message_read', {
          messageId: data.messageId,
          readAt: new Date().toISOString(),
        });
      }
    } catch (error) {
      this.logger.error(`Failed to mark message read: ${error.message}`);
    }
  }

  @SubscribeMessage('mark_chat_read')
  async handleMarkChatRead(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { conversationId: number },
  ) {
    try {
      const result = await this.chatsService.markChatRead(
        data.conversationId,
        client.userId,
      );

      // Notify other participant about read receipts
      return { event: 'chat_marked_read', data: { markedCount: result.count } };
    } catch (error) {
      this.logger.error(`Failed to mark chat read: ${error.message}`);
    }
  }

  // Helper method to emit new messages after REST API creates them
  emitNewMessage(conversationId: number, message: any) {
    const roomName = `conversation:${conversationId}`;
    this.server.to(roomName).emit('new_message', message);
  }

  // Helper to emit to specific user across all their sockets
  private emitToUser(userId: number, event: string, data: any) {
    const socketIds = this.userSockets.get(userId);
    if (socketIds) {
      socketIds.forEach((socketId) => {
        this.server.to(socketId).emit(event, data);
      });
    }
  }

  // Check if user is online
  isUserOnline(userId: number): boolean {
    return (
      this.userSockets.has(userId) && this.userSockets.get(userId)!.size > 0
    );
  }

  // Get last seen time
  getUserLastSeen(userId: number): Date | null {
    return this.lastSeen.get(userId) || null;
  }

  private extractToken(client: Socket): string | null {
    // Try to get token from Authorization header
    const authHeader = client.handshake.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }

    // Try to get from query params (fallback)
    const token = client.handshake.auth?.token || client.handshake.query?.token;
    return token ? String(token) : null;
  }
}
