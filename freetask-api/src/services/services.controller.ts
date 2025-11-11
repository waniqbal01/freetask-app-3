import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ServicesService } from './services.service';
import { CreateServiceDto } from './dto/create-service.dto';
import { UpdateServiceDto } from './dto/update-service.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { GetUser } from '../common/decorators/get-user.decorator';
import { AuthUser } from '../auth/types/auth-user.type';

@Controller('services')
export class ServicesController {
  constructor(private readonly servicesService: ServicesService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(@GetUser() user: AuthUser, @Body() dto: CreateServiceDto) {
    return this.servicesService.create(user.id, user.role, dto);
  }

  @Get()
  findAll() {
    return this.servicesService.findAll();
  }

  @Get('categories')
  categories() {
    return this.servicesService.categories();
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.servicesService.findOne(id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @GetUser() user: AuthUser,
    @Body() dto: UpdateServiceDto,
  ) {
    return this.servicesService.update(id, user.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number, @GetUser() user: AuthUser) {
    return this.servicesService.remove(id, user.id);
  }
}
