import { Type, Transform } from 'class-transformer';
import {
  IsArray,
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @IsEmail()
  email: string;

  @IsNotEmpty()
  @MinLength(8)
  @MaxLength(32)
  @Matches(/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_])/, {
    message: 'Kata laluan mesti mengandungi huruf besar, huruf kecil, nombor dan simbol',
  })
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
  @IsString()
  state?: string;

  @IsOptional()
  @IsString()
  district?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  skills?: string[];

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  rate?: number;
}
