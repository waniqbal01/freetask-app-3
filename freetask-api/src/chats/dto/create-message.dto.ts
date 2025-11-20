import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CreateMessageDto {
  @ApiProperty({ example: 'Hi, I have started working on your request.' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  content: string;
}
