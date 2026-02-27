import { Body, Controller, Get, Param, Patch, UseGuards, Query } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) { }

  @Get('freelancers')
  async getFreelancers(
    @Query('q') q?: string,
    @Query('category') category?: string,
    @Query('state') state?: string,
    @Query('district') district?: string,
  ) {
    return this.usersService.getFreelancers({ q, category, state, district });
  }

  @Get('me')
  getMe(@GetUser('userId') userId: number) {
    return this.usersService.getProfile(userId);
  }

  @Patch('me')
  updateMe(@GetUser('userId') userId: number, @Body() dto: UpdateUserDto) {
    return this.usersService.updateProfile(userId, dto);
  }

  @Get('pending-bank-verification')
  // @Roles('ADMIN') // TODO: Uncomment when RolesGuard is ready/imported
  // @UseGuards(JwtAuthGuard, RolesGuard)
  async getPendingBankVerifications() {
    return this.usersService.findPendingBankVerifications();
  }

  @Get(':id')
  async getPublicProfile(@Param('id') id: string) {
    return this.usersService.getPublicProfile(Number(id));
  }

  @Patch(':id/verify-bank')
  // @Roles('ADMIN')
  // @UseGuards(JwtAuthGuard, RolesGuard)
  async verifyBankDetails(@Param('id') id: string) {
    return this.usersService.verifyBankDetails(Number(id));
  }
}
