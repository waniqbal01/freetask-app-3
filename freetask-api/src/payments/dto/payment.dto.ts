import { IsInt, IsString, IsOptional, IsDecimal } from 'class-validator';

export class CreatePaymentDto {
    @IsInt()
    jobId: number;

    @IsString()
    @IsOptional()
    paymentMethod?: string;

    @IsString()
    @IsOptional()
    paymentGateway?: string;
}

export class VerifyPaymentDto {
    @IsInt()
    jobId: number;

    @IsString()
    transactionId: string;
}
