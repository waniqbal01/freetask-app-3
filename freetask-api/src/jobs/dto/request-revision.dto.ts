import { IsString, IsNotEmpty } from 'class-validator';

export class RequestRevisionDto {
    @IsString()
    @IsNotEmpty()
    reason: string;
}
