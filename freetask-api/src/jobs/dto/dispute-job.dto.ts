import { IsString } from 'class-validator';

export class DisputeJobDto {
  @IsString()
  reason: string;
}
