import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { ServicesService } from './services.service';
import { CreateServiceDto } from './dto/create-service.dto';
import { UpdateServiceDto } from './dto/update-service.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../auth/get-user.decorator';
import { UserRole } from '@prisma/client';

@ApiTags('Services')
@Controller('services')
export class ServicesController {
  constructor(private readonly servicesService: ServicesService) {}

  @ApiOperation({ summary: 'Create a new freelancer service listing' })
  @ApiResponse({ status: 201, description: 'Service created' })
  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @GetUser('userId') userId: number,
    @GetUser('role') role: UserRole,
    @Body() dto: CreateServiceDto,
  ) {
    return this.servicesService.create(userId, role, dto);
  }

  @ApiOperation({ summary: 'Browse or filter services' })
  @Get()
  findAll(
    @Query('q') q?: string,
    @Query('category') category?: string,
    @Query('freelancerId') freelancerId?: string,
  ) {
    const parsedFreelancerId = freelancerId ? Number(freelancerId) : undefined;
    return this.servicesService.findAll(q, category, parsedFreelancerId);
  }

  @ApiOperation({ summary: 'List services for the authenticated freelancer' })
  @UseGuards(JwtAuthGuard)
  @Get('mine')
  findMine(@GetUser('userId') userId: number) {
    return this.servicesService.findMine(userId);
  }

  @ApiOperation({ summary: 'List available categories' })
  @Get('categories')
  categories(): Promise<string[]> {
    return this.servicesService.categories();
  }

  @ApiOperation({ summary: 'Get service details' })
  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.servicesService.findOne(id);
  }

  @ApiOperation({ summary: 'Update a service listing' })
  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @GetUser('userId') userId: number,
    @Body() dto: UpdateServiceDto,
  ) {
    return this.servicesService.update(id, userId, dto);
  }

  @ApiOperation({ summary: 'Delete a service listing' })
  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number, @GetUser('userId') userId: number) {
    return this.servicesService.remove(id, userId);
  }
}
