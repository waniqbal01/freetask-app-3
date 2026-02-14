import { Type } from 'class-transformer';
import {
    IsInt,
    IsNotEmpty,
    IsOptional,
    IsString,
    Min,
    MinLength,
} from 'class-validator';

    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    serviceId?: number;

    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    freelancerId?: number;

    @IsString()
    @IsNotEmpty()
    message: string;
}
