import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateMessageDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  content: string;

  @IsString()
  @IsOptional()
  type?: string;

  @IsString()
  @IsOptional()
  attachmentUrl?: string;
}
