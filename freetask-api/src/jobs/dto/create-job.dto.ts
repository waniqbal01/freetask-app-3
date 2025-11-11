import { Type } from 'class-transformer';
import { IsInt, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateJobDto {
  @Type(() => Number)
  @IsInt()
  serviceId: number;

  @IsOptional()
  @IsString()
  @MinLength(3)
  title?: string;

  @IsString()
  @IsNotEmpty()
  description: string;
}
