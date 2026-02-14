import { Type, Transform } from 'class-transformer';
import {
  IsArray,
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @IsEmail()
  email: string;

  @IsNotEmpty()
  @MinLength(6)
  password: string;

  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  @IsIn(['CLIENT', 'FREELANCER'], {
    message: 'Role must be CLIENT or FREELANCER',
  })
  @Transform(({ value }) => value?.toString().toUpperCase())
  role: string;

  @IsOptional()
  @IsString()
  @Transform(({ value, obj }) => value ?? obj.avatar)
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  /**
   * @deprecated Use avatarUrl instead. This field will be removed in v2.
   * Kept for backward compatibility with legacy clients.
   * Automatically mapped to avatarUrl via Transform decorator above.
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
}
