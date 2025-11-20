import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { ChatsService } from './chats.service';
import { CreateMessageDto } from './dto/create-message.dto';
import { ChatMessageDto } from './dto/chat-message.dto';
import { JobStatus } from '@prisma/client';

interface JoinJobRoomPayload {
  jobId: number | string;
}

interface SendMessagePayload extends JoinJobRoomPayload {
  content: string;
}

@WebSocketGateway({
  namespace: '/chats',
  cors: { origin: '*', credentials: true },
})
// NOTE: HTTP endpoints remain the primary source of truth for chats.
// This gateway is a best-effort enhancement for realtime updates during MVP.
export class ChatsGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(ChatsGateway.name);
  private readonly joinedRooms = new Map<string, Set<number>>();

  constructor(
    private readonly chatsService: ChatsService,
    private readonly jwtService: JwtService,
  ) {}

  @WebSocketServer()
  private server?: Server;

  async handleConnection(client: Socket) {
    try {
      const userId = this.resolveUserId(client);
      client.data.userId = userId;
      this.logger.debug(`Client ${client.id} authenticated as ${userId}`);
    } catch (error) {
      this.logger.warn(`Disconnecting client ${client.id}: ${error}`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    this.joinedRooms.delete(client.id);
  }

  @SubscribeMessage('joinJobRoom')
  async handleJoinJobRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: JoinJobRoomPayload,
  ) {
    const userId = this.getUserId(client);
    const jobId = this.parseJobId(payload?.jobId);
    if (!jobId) {
      throw new WsException('Job ID is required');
    }

    await this.chatsService.ensureJobParticipant(jobId, userId);

    await client.join(this.getRoomName(jobId));
    const rooms = this.joinedRooms.get(client.id) ?? new Set<number>();
    rooms.add(jobId);
    this.joinedRooms.set(client.id, rooms);

    return { status: 'ok', jobId };
  }

  @SubscribeMessage('sendMessage')
  async handleSendMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: SendMessagePayload,
  ) {
    const userId = this.getUserId(client);
    const jobId = this.parseJobId(payload?.jobId);
    const content = payload?.content?.trim();

    if (!jobId || !content) {
      throw new WsException('Invalid message payload');
    }

    const dto = { content } satisfies CreateMessageDto;
    const message = await this.chatsService.postMessage(jobId, userId, dto);
    const event = this.emitNewMessage(jobId, message);

    return event;
  }

  emitNewMessage(jobId: number, message: ChatMessageDto) {
    const payload = { ...message, jobId };
    this.server?.to(this.getRoomName(jobId)).emit('messageReceived', payload);
    return payload;
  }

  emitJobStatusUpdate(job: {
    id: number;
    status: JobStatus;
    disputeReason?: string | null;
    title: string;
    updatedAt: Date;
  }) {
    const payload = {
      jobId: job.id,
      status: job.status,
      disputeReason: job.disputeReason ?? undefined,
      title: job.title,
      updatedAt: job.updatedAt,
    };
    this.server?.to(this.getRoomName(job.id)).emit('jobStatusUpdated', payload);
    return payload;
  }

  private resolveUserId(client: Socket): number {
    const token =
      (client.handshake.auth?.token as string | undefined) ??
      this.extractToken(client.handshake.headers['authorization']) ??
      this.extractToken(client.handshake.query?.token);

    if (!token) {
      throw new WsException('Unauthorized');
    }

    try {
      const payload = this.jwtService.verify<{ sub: number }>(token, {
        secret: process.env.JWT_SECRET,
      });
      return payload.sub;
    } catch (error) {
      throw new WsException('Unauthorized');
    }
  }

  private extractToken(source?: string | string[] | unknown): string | undefined {
    if (!source) {
      return undefined;
    }
    const header = Array.isArray(source) ? source[0] : source;
    if (typeof header !== 'string') {
      return undefined;
    }
    if (!header) {
      return undefined;
    }
    if (header.startsWith('Bearer ')) {
      return header.slice(7);
    }
    return header;
  }

  private getUserId(client: Socket): number {
    const userId = client.data.userId as number | undefined;
    if (!userId) {
      throw new WsException('Unauthorized');
    }
    return userId;
  }

  private parseJobId(value?: number | string): number {
    const numeric = typeof value === 'number' ? value : Number(value);
    if (!Number.isFinite(numeric)) {
      throw new WsException('Invalid job identifier');
    }
    return numeric;
  }

  private getRoomName(jobId: number): string {
    return `job:${jobId}`;
  }
}
