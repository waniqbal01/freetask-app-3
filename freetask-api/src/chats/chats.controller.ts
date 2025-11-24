import { Body, Controller, Get, Param, ParseIntPipe, Post, Query, UseGuards } from '@nestjs/common';
import { ChatsService } from './chats.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { CreateMessageDto } from './dto/create-message.dto';
import { UserRole } from '@prisma/client';
import { Throttle } from '@nestjs/throttler';
import { PaginationQueryDto } from '../common/dto/pagination-query.dto';

@Controller('chats')
@UseGuards(JwtAuthGuard)
export class ChatsController {
  constructor(private readonly chatsService: ChatsService) {}

  @Get()
  @Throttle(15, 60)
  listThreads(
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Query() query?: PaginationQueryDto,
  ) {
    return this.chatsService.listThreads(userId, role, { limit: query?.limit, offset: query?.offset });
  }

  @Get(':jobId/messages')
  @Throttle(25, 60)
  listMessages(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Query() query?: PaginationQueryDto,
  ) {
    return this.chatsService.listMessages(jobId, userId, role, { limit: query?.limit, offset: query?.offset });
  }

  @Post(':jobId/messages')
  sendMessage(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Body() dto: CreateMessageDto,
  ) {
    return this.chatsService.postMessage(jobId, userId, role, dto);
  }
}
