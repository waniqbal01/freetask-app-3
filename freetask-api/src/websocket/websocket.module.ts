import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ChatGateway } from './chat.gateway';
import { WsJwtGuard } from './ws-jwt.guard';
import { forwardRef } from '@nestjs/common';
import { ChatsModule } from '../chats/chats.module';

@Module({
    imports: [
        JwtModule.register({
            secret: process.env.JWT_SECRET,
            signOptions: { expiresIn: '7d' },
        }),
        forwardRef(() => ChatsModule),
    ],
    providers: [ChatGateway, WsJwtGuard],
    exports: [ChatGateway],
})
export class WebsocketModule { }
