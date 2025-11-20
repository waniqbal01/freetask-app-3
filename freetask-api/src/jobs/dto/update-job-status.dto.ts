import { ApiProperty } from '@nestjs/swagger';
import { IsEnum } from 'class-validator';
import { JobStatus } from '@prisma/client';

export class UpdateJobStatusDto {
  @ApiProperty({ enum: JobStatus })
  @IsEnum(JobStatus)
  status: JobStatus;
}
