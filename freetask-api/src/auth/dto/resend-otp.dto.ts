import { IsEmail } from 'class-validator';

export class ResendOtpDto {
    @IsEmail({}, { message: 'Sila masukkan e-mel yang sah' })
    email: string;
}
