import { IsEnum, IsString, IsOptional, IsNumber } from 'class-validator';

export class ResolveDisputeDto {
  @IsEnum(['RELEASE', 'REFUND', 'PARTIAL'])
  resolution: 'RELEASE' | 'REFUND' | 'PARTIAL';

  @IsOptional()
  @IsNumber()
  refundAmount?: number;

  @IsOptional()
  @IsString()
  notes?: string;
}
