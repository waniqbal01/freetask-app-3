import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type, Transform } from 'class-transformer';
import {
  IsArray,
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';
import { UserRole } from '@prisma/client';

export class RegisterDto {
  @ApiProperty({ example: 'freelancer@email.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ minLength: 6 })
  @IsNotEmpty()
  @MinLength(6)
  password: string;

  @ApiProperty({ example: 'Ain Freelancer' })
  @IsNotEmpty()
  name: string;

  @ApiProperty({ enum: UserRole, description: 'CLIENT or FREELANCER' })
  @IsEnum(UserRole)
  role: UserRole;

  @ApiPropertyOptional({ description: 'Avatar URL from previous upload' })
  @IsOptional()
  @IsString()
  @Transform(({ value, obj }) => value ?? obj.avatar)
  avatarUrl?: string;

  @ApiPropertyOptional({ description: 'Alias for avatarUrl used by Flutter' })
  @IsOptional()
  @IsString()
  // Accepts `avatar` from Flutter payloads and maps it to `avatarUrl` in the service layer.
  avatar?: string;

  @ApiPropertyOptional({ description: 'Short professional bio' })
  @IsOptional()
  @IsString()
  bio?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  skills?: string[];

  @ApiPropertyOptional({ example: 75, description: 'Hourly rate in local currency' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  rate?: number;
}
