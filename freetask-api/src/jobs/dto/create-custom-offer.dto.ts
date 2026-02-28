import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  MinLength,
} from 'class-validator';
import { JOB_MIN_AMOUNT, JOB_MIN_DESC_LEN } from '../constants';

export class CreateCustomOfferDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  clientId: number;

  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  title: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(JOB_MIN_DESC_LEN)
  description: string;

  @Type(() => Number)
  @IsNotEmpty()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(JOB_MIN_AMOUNT)
  amount: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  attachments?: string[];
}
