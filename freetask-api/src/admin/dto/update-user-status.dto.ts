import { IsEnum, IsOptional, IsString } from 'class-validator';

export class UpdateUserStatusDto {
  @IsEnum(['ACTIVE', 'BANNED'])
  status: 'ACTIVE' | 'BANNED';

  @IsOptional()
  @IsString()
  reason?: string;
}
