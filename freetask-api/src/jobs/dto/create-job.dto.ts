import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  MinLength,
} from 'class-validator';

export class CreateJobDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  serviceId: number;

  @IsOptional()
  @IsString()
  @MinLength(3)
  title?: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(5)
  description: string;

  @Type(() => Number)
  @IsNotEmpty()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;
}
