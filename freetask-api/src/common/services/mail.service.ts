import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';

@Injectable()
export class MailService {
    private readonly logger = new Logger(MailService.name);
    private resend: Resend;
    private defaultFrom: string;

    constructor(private readonly configService: ConfigService) {
        const apiKey = this.configService.get<string>('RESEND_API_KEY');
        this.resend = new Resend(apiKey);
        this.defaultFrom = this.configService.get<string>('RESEND_FROM_EMAIL') || 'Freetask <noreply@freetask.app>';
    }

    async sendOtpEmail(to: string, otpCode: string, name: string) {
        try {
            const data = await this.resend.emails.send({
                from: this.defaultFrom,
                to,
                subject: 'Freetask - Kod Pengesahan OTP Anda',
                html: `
          <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
            <h2>Selamat Datang ke Freetask, ${name}!</h2>
            <p>Terima kasih kerana mendaftar. Untuk melengkapkan pendaftaran anda, sila masukkan Kod Pengesahan (OTP) 6-digit di bawah pada aplikasi/web:</p>
            <div style="margin: 20px 0; padding: 15px; background-color: #f4f4f4; border-radius: 5px; text-align: center;">
              <h1 style="letter-spacing: 5px; color: #007bff; margin: 0;">${otpCode}</h1>
            </div>
            <p>Kod ini hanya sah selama 10 minit.</p>
            <p>Jika anda tidak membuat permintaan ini, sila abaikan e-mel ini.</p>
            <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;" />
            <p style="font-size: 12px; color: #999;">Ini adalah mesej automatik. Sila jangan balas mesej ini.</p>
          </div>
        `,
            });

            this.logger.log(`OTP email sent to ${to}, id: ${data?.data?.id}`);
            return data;
        } catch (error) {
            this.logger.error(`Failed to send OTP email to ${to}`, error);
            throw error;
        }
    }
}
