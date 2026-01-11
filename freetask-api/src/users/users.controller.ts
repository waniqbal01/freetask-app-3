import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) { }

  @Get('me')
  getMe(@GetUser('userId') userId: number) {
    return this.usersService.getProfile(userId);
  }

  @Get(':id')
  async getPublicProfile(@Param('id') id: string) {
    return this.usersService.getPublicProfile(Number(id));
  }

  @Patch('me')
  updateMe(@GetUser('userId') userId: number, @Body() dto: UpdateUserDto) {
    return this.usersService.updateProfile(userId, dto);
  }
}
