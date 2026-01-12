import { IsString, IsOptional, IsArray } from 'class-validator';

export class SubmitJobDto {
    @IsString()
    @IsOptional()
    message?: string;

    @IsArray()
    @IsString({ each: true })
    @IsOptional()
    attachments?: string[];
}
