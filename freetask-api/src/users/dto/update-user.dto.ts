import { Type, Transform } from 'class-transformer';
import { IsArray, IsNumber, IsOptional, IsString, IsBoolean, IsIn } from 'class-validator';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  @Transform(({ value, obj }) => value ?? obj.avatar)
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  /**
   * @deprecated Use avatarUrl instead. This field will be removed in v2.
   * Accepts `avatar` from Flutter payloads and maps it to `avatarUrl` in the service layer.
   */
  avatar?: string;

  @IsOptional()
  @IsString()
  bio?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  skills?: string[];

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  rate?: number;

  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @IsOptional()
  @IsString()
  location?: string;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;

  @IsOptional()
  @IsIn([
    'MBBEMYKL', 'BCBBMYKL', 'PBBEMYKL', 'RHBBMYKL', 'HLBBMYKL',
    'AMBBMYKL', 'BIMBMYKL', 'BKRM', 'BMMB', 'BSN'
  ], { message: 'Invalid Bank Code. Must be a valid Billplz code.' })
  @IsString()
  bankCode?: string;

  @IsOptional()
  @IsString()
  bankAccount?: string;

  @IsOptional()
  @IsString()
  bankHolderName?: string;
}
