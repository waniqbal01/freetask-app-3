import { Module } from '@nestjs/common';
import { ChatsService } from './chats.service';
import { ChatsController } from './chats.controller';
import { WebsocketModule } from '../websocket/websocket.module';
import { forwardRef } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [forwardRef(() => WebsocketModule), NotificationsModule],
  controllers: [ChatsController],
  providers: [ChatsService],
  exports: [ChatsService],
})
export class ChatsModule {}
