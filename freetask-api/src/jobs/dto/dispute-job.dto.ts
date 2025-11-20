import { ApiProperty } from '@nestjs/swagger';
import { IsString } from 'class-validator';

export class DisputeJobDto {
  @ApiProperty({ example: 'Freelancer stopped responding' })
  @IsString()
  reason: string;
}
