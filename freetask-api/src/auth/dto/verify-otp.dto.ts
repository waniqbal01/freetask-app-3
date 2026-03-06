import { IsEmail, IsNotEmpty, IsString, Length } from 'class-validator';

export class VerifyOtpDto {
    @IsEmail({}, { message: 'Sila masukkan e-mel yang sah' })
    email: string;

    @IsString()
    @IsNotEmpty({ message: 'Sila masukkan Kod OTP' })
    @Length(6, 6, { message: 'Kod OTP mestilah 6 digit' })
    otp: string;
}
