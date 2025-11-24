import { IsNotEmpty, IsString, MinLength } from 'class-validator';
import { JOB_MIN_DISPUTE_REASON_LEN } from '../constants';

export class DisputeJobDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(JOB_MIN_DISPUTE_REASON_LEN)
  reason: string;
}
