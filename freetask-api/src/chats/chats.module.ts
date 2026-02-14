import { Module } from '@nestjs/common';
import { ChatsService } from './chats.service';
import { ChatsController } from './chats.controller';
import { WebsocketModule } from '../websocket/websocket.module';
import { forwardRef } from '@nestjs/common';

@Module({
  imports: [forwardRef(() => WebsocketModule)],
  controllers: [ChatsController],
  providers: [ChatsService],
  exports: [ChatsService],
})
export class ChatsModule {}
