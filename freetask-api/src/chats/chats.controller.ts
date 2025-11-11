import { Body, Controller, Get, Param, ParseIntPipe, Post, UseGuards } from '@nestjs/common';
import { ChatsService } from './chats.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { GetUser } from '../common/decorators/get-user.decorator';
import { AuthUser } from '../auth/types/auth-user.type';
import { CreateMessageDto } from './dto/create-message.dto';

@Controller('chats')
@UseGuards(JwtAuthGuard)
export class ChatsController {
  constructor(private readonly chatsService: ChatsService) {}

  @Get(':jobId/messages')
  listMessages(@Param('jobId', ParseIntPipe) jobId: number, @GetUser() user: AuthUser) {
    return this.chatsService.listMessages(jobId, user.id);
  }

  @Post(':jobId/messages')
  sendMessage(
    @Param('jobId', ParseIntPipe) jobId: number,
    @GetUser() user: AuthUser,
    @Body() dto: CreateMessageDto,
  ) {
    return this.chatsService.postMessage(jobId, user.id, dto);
  }
}
