import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { PrismaModule } from './prisma/prisma.module';
import { ServicesModule } from './services/services.module';
import { JobsModule } from './jobs/jobs.module';
import { ChatsModule } from './chats/chats.module';
import { UsersModule } from './users/users.module';
import { UploadsModule } from './uploads/uploads.module';
import { ReviewsModule } from './reviews/reviews.module';
import { HealthController } from './health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
    AuthModule,
    ServicesModule,
    JobsModule,
    ChatsModule,
    UploadsModule,
    ReviewsModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
