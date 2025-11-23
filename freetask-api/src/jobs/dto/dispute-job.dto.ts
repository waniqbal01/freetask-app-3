import { IsNotEmpty, IsString } from 'class-validator';

export class DisputeJobDto {
  @IsString()
  @IsNotEmpty()
  reason: string;
}
