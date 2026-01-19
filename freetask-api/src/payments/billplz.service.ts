import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance } from 'axios';
import * as crypto from 'crypto';

@Injectable()
export class BillplzService {
  private readonly logger = new Logger(BillplzService.name);
  private client: AxiosInstance;
  private apiKey: string;
  private signatureKey: string;
  private collectionId: string;

  constructor(private configService: ConfigService) {
    this.apiKey = this.configService.get<string>('BILLPLZ_API_KEY') || '';
    this.signatureKey = this.configService.get<string>('BILLPLZ_X_SIGNATURE_KEY') || '';
    this.collectionId = this.configService.get<string>('BILLPLZ_COLLECTION_ID') || '';

    this.client = axios.create({
      baseURL: 'https://www.billplz.com/api/v4', // Use sandbox URL for testing if needed: https://www.billplz-sandbox.com/api/v4
      auth: {
        username: this.apiKey,
        password: '',
      },
      timeout: 10000,
    });
  }

  async createCollection(
    title: string,
    amountInCents: number,
    email: string,
    name: string,
    description: string,
    callbackUrl: string,
    redirectUrl: string,
  ) {
    try {
      // If collectionId is not set in env, we might need to create one dynamically or use a default
      // For this implementation, we assume a single collection ID is used for the app
      if (!this.collectionId) {
        this.logger.warn('BILLPLZ_COLLECTION_ID is not set. Payment creation might fail if not passing collection_id.');
      }

      const response = await this.client.post('/bills', {
        collection_id: this.collectionId,
        email: email,
        mobile: null,
        name: name,
        amount: amountInCents,
        callback_url: callbackUrl,
        redirect_url: redirectUrl,
        description: description,
      });

      return response.data;
    } catch (error) {
      this.logger.error('Error creating Billplz bill', error.response?.data || error.message);
      throw error;
    }
  }

  verifyXSignature(payload: any, signature: string): boolean {
    if (!this.signatureKey) {
      this.logger.warn('BILLPLZ_X_SIGNATURE_KEY is not set. Skipping signature verification.');
      return true; // Skip verification if key is missing (dev mode)
    }

    // Billplz X-Signature generation:
    // https://www.billplz.com/api#x-signature
    const sourceString = `amount${payload.amount}|collection_id${payload.collection_id}|due_at${payload.due_at}|email${payload.email}|id${payload.id}|mobile${payload.mobile}|name${payload.name}|paid_amount${payload.paid_amount}|paid_at${payload.paid_at}|paid_at_readable${payload.paid_at_readable}|state${payload.state}|url${payload.url}|x_signature${this.signatureKey}`;

    const generatedSignature = crypto.createHmac('sha256', this.signatureKey).update(sourceString).digest('hex');

    return generatedSignature === signature;
  }
}
