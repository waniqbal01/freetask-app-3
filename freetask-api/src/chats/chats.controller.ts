import { Body, Controller, Get, Param, ParseIntPipe, Post, Query, UseGuards, Logger } from '@nestjs/common';
import { ChatsService } from './chats.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { CreateMessageDto } from './dto/create-message.dto';
import { UserRole } from '@prisma/client';
import { Throttle } from '@nestjs/throttler';
import { PaginationQueryDto } from '../common/dto/pagination-query.dto';
import { ChatGateway } from '../websocket/chat.gateway';

@Controller('chats')
@UseGuards(JwtAuthGuard)
export class ChatsController {
  private readonly logger = new Logger(ChatsController.name);

  constructor(
    private readonly chatsService: ChatsService,
    private readonly chatGateway: ChatGateway,
  ) { }

  @Get()
  @Throttle({ default: { limit: 15, ttl: 60000 } })
  listThreads(
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Query() query?: PaginationQueryDto,
  ) {
    return this.chatsService.listThreads(userId, role, { limit: query?.limit, offset: query?.offset });
  }

  @Post('conversation')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  createConversation(
    @GetUser('userId') userId: number,
    @Body('otherUserId', ParseIntPipe) otherUserId: number,
  ) {
    return this.chatsService.getOrCreateConversation(userId, otherUserId);
  }

  @Get(':conversationId/messages')
  @Throttle({ default: { limit: 25, ttl: 60000 } })
  listMessages(
    @Param('conversationId', ParseIntPipe) conversationId: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Query() query?: PaginationQueryDto,
  ) {
    return this.chatsService.listMessages(conversationId, userId, role, { limit: query?.limit, offset: query?.offset });
  }

  @Post(':conversationId/messages')
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  async sendMessage(
    @Param('conversationId', ParseIntPipe) conversationId: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Body() dto: CreateMessageDto,
  ) {
    this.logger.log(`Message sent by user ${userId} in conversation ${conversationId}`);

    const message = await this.chatsService.postMessage(conversationId, userId, role, dto);

    // Broadcast via WebSocket
    this.chatGateway.emitNewMessage(conversationId, message);

    return message;
  }

  @Post(':conversationId/mark-read')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  markChatRead(
    @Param('conversationId', ParseIntPipe) conversationId: number,
    @GetUser('userId') userId: number,
  ) {
    return this.chatsService.markChatRead(conversationId, userId);
  }
}
