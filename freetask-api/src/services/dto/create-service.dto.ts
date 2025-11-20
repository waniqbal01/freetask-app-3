import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsNotEmpty, IsNumber, IsPositive, IsString, MaxLength } from 'class-validator';

export class CreateServiceDto {
  @ApiProperty({ example: 'Logo Design' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  title: string;

  @ApiProperty({ example: 'Custom logo delivered with two revisions.' })
  @IsString()
  @IsNotEmpty()
  description: string;

  @ApiProperty({ example: 250 })
  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  price: number;

  @ApiProperty({ example: 'Design' })
  @IsString()
  @IsNotEmpty()
  category: string;
}
