import { Type } from 'class-transformer';
import {
    IsInt,
    IsNotEmpty,
    IsOptional,
    IsString,
    Min,
    MinLength,
} from 'class-validator';

export class CreateInquiryDto {
    @Type(() => Number)
    @IsInt()
    @Min(1)
    serviceId: number;

    @IsString()
    @IsNotEmpty()
    message: string;
}
