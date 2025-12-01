import { IsNotEmpty, IsString, MaxLength, MinLength } from 'class-validator';
import { JOB_MIN_DISPUTE_REASON_LEN } from '../constants';

export class DisputeJobDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(JOB_MIN_DISPUTE_REASON_LEN)
  @MaxLength(500)
  reason: string;
}
