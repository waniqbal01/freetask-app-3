import { IsString, IsOptional } from 'class-validator';

export class ProcessWithdrawalDto {
  @IsOptional()
  @IsString()
  reason?: string;
}
