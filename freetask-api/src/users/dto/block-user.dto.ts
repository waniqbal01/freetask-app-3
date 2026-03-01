import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class BlockUserDto {
    @IsOptional()
    @IsString()
    reason?: string;

    @IsOptional()
    @IsBoolean()
    isReported?: boolean;
}
