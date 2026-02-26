import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { UsersCron } from './users.cron';

@Module({
  providers: [UsersService, UsersCron],
  controllers: [UsersController],
  exports: [UsersService],
})
export class UsersModule { }
