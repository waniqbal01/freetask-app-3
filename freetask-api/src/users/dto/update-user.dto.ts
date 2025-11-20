import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type, Transform } from 'class-transformer';
import { IsArray, IsNumber, IsOptional, IsString } from 'class-validator';

export class UpdateUserDto {
  @ApiPropertyOptional({ example: 'Updated Name' })
  @IsOptional()
  @IsString()
  name?: string;

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

  @ApiPropertyOptional({ example: 100, description: 'Hourly rate in local currency' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  rate?: number;
}
