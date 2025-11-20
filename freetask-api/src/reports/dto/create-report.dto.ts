import { IsInt, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateReportDto {
  @IsOptional()
  @IsInt()
  reportedUserId?: number;

  @IsOptional()
  @IsInt()
  reportedServiceId?: number;

  @IsString()
  @MaxLength(500)
  reason: string;
}
