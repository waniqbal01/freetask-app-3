import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsOptional, IsString } from 'class-validator';

export class UpdateDeviceTokenDto {
  @ApiPropertyOptional({ example: 'fcm-device-token' })
  @IsOptional()
  @IsString()
  @Transform(({ value }) => {
    if (value === null || value === undefined) {
      return null;
    }
    const token = value.toString().trim();
    return token.length ? token : null;
  })
  deviceToken?: string | null;
}
