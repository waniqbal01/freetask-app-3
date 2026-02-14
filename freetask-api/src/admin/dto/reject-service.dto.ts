import { IsString, IsOptional } from 'class-validator';

export class RejectServiceDto {
  @IsString()
  reason: string;
}
