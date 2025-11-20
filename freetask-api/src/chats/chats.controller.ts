import { Body, Controller, Get, Param, ParseIntPipe, Post, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ChatsService } from './chats.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { CreateMessageDto } from './dto/create-message.dto';
import { ChatsGateway } from './chats.gateway';

@ApiTags('Chats')
@Controller('chats')
@UseGuards(JwtAuthGuard)
export class ChatsController {
  constructor(
    private readonly chatsService: ChatsService,
    private readonly chatsGateway: ChatsGateway,
  ) {}

  @ApiOperation({ summary: 'List chat threads for the user' })
  @Get()
  listThreads(@GetUser('userId') userId: number) {
    return this.chatsService.listThreads(userId);
  }

  @ApiOperation({ summary: 'Load messages for a job chat' })
  @Get(':jobId/messages')
  listMessages(@Param('jobId', ParseIntPipe) jobId: number, @GetUser('userId') userId: number) {
    return this.chatsService.listMessages(jobId, userId);
  }

  @ApiOperation({ summary: 'Send a message to a job chat' })
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
