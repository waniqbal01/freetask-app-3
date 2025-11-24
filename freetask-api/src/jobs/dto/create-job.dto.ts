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
import { JOB_MIN_AMOUNT, JOB_MIN_DESC_LEN } from '../constants';

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
  @MinLength(JOB_MIN_DESC_LEN)
  description: string;

  @Type(() => Number)
  @IsNotEmpty()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(JOB_MIN_AMOUNT)
  amount: number;
}
