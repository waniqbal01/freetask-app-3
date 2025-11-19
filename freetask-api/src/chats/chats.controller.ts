import { Body, Controller, Get, Param, ParseIntPipe, Post, UseGuards } from '@nestjs/common';
import { ChatsService } from './chats.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { CreateMessageDto } from './dto/create-message.dto';
import { ChatsGateway } from './chats.gateway';

@Controller('chats')
@UseGuards(JwtAuthGuard)
export class ChatsController {
  constructor(
    private readonly chatsService: ChatsService,
    private readonly chatsGateway: ChatsGateway,
  ) {}

  @Get()
  listThreads(@GetUser('userId') userId: number) {
    return this.chatsService.listThreads(userId);
  }

  @Get(':jobId/messages')
  listMessages(@Param('jobId', ParseIntPipe) jobId: number, @GetUser('userId') userId: number) {
    return this.chatsService.listMessages(jobId, userId);
  }

  @Post(':jobId/messages')
  sendMessage(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser('userId') userId: number,
    @Body() dto: CreateMessageDto,
  ) {
    return this.chatsService
      .postMessage(jobId, userId, dto)
      .then((message) => {
        this.chatsGateway.emitNewMessage(jobId, message);
        return message;
      });
  }
}
