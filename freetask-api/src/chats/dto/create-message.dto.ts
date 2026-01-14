import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateMessageDto {
  @IsString()
  @IsOptional()
  @MaxLength(1000)
  content?: string;

  @IsString()
  @IsOptional()
  type?: string;

  @IsString()
  @IsOptional()
  attachmentUrl?: string;
}
