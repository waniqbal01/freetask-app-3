import {
  Injectable,
  Logger,
  UnauthorizedException,
  BadRequestException,
  ServiceUnavailableException,
  InternalServerErrorException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance } from 'axios';
import * as crypto from 'crypto';

export interface BillplzPayload {
  id: string;
  collection_id: string;
  paid: boolean;
  state: string;
  amount: number;
  paid_amount: number;
  due_at: string;
  email: string;
  mobile: string | null;
  name: string;
  url: string;
  paid_at?: string;
  paid_at_readable?: string;
}

@Injectable()
export class BillplzService {
  private readonly logger = new Logger(BillplzService.name);
  private client: AxiosInstance;
  private apiKey: string;
  private signatureKey: string;
  private collectionId: string;

  constructor(private configService: ConfigService) {
    // Get environment variables with proper type handling
    this.apiKey = this.configService.get<string>('BILLPLZ_API_KEY') ?? '';
    this.signatureKey =
      this.configService.get<string>('BILLPLZ_X_SIGNATURE_KEY') ?? '';
    this.collectionId =
      this.configService.get<string>('BILLPLZ_COLLECTION_ID') ?? '';

    this.logger.log(
      `Billplz Config Loaded - API Key set: ${!!this.apiKey}, Collection ID: ${this.collectionId}, Sandbox: ${this.configService.get('BILLPLZ_SANDBOX')}`,
    );

    // Check for sandbox mode
    const sandboxEnv = this.configService.get('BILLPLZ_SANDBOX');
    const isSandbox = sandboxEnv === 'true' || sandboxEnv === true;

    this.logger.log(
      `Billplz Mode: ${isSandbox ? 'SANDBOX' : 'PRODUCTION'} (Value: ${sandboxEnv})`,
    );

    const baseURL = isSandbox
      ? 'https://www.billplz-sandbox.com/api/v3'
      : 'https://www.billplz.com/api/v3';

    if (isSandbox) {
      this.logger.warn('⚠️  Using Billplz SANDBOX mode for testing');
    }

    // Validate required credentials
    if (!this.apiKey) {
      this.logger.error('BILLPLZ_API_KEY is not set!');
    }

    this.client = axios.create({
      baseURL,
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
      // Validate required credentials before making API call
      if (!this.apiKey) {
        this.logger.error('❌ BILLPLZ_API_KEY is not configured!');
        throw new InternalServerErrorException(
          'Billplz API Key is missing. Please configure BILLPLZ_API_KEY in .env file',
        );
      }

      if (!this.collectionId) {
        this.logger.error('❌ BILLPLZ_COLLECTION_ID is not configured!');
        throw new InternalServerErrorException(
          'Billplz Collection ID is missing. Please configure BILLPLZ_COLLECTION_ID in .env file',
        );
      }

      const payload = {
        collection_id: this.collectionId,
        email: email,
        mobile: null,
        name: name,
        amount: amountInCents,
        callback_url: callbackUrl,
        redirect_url: redirectUrl,
        description: description,
      };

      this.logger.log(
        `📤 Creating Billplz bill for ${email} - RM${(amountInCents / 100).toFixed(2)}`,
      );
      this.logger.debug(`Request payload: ${JSON.stringify(payload, null, 2)}`);

      const response = await this.client.post('/bills', payload);

      this.logger.log(
        `✅ Billplz bill created successfully - ID: ${response.data.id}`,
      );
      this.logger.debug(
        `Billplz response: ${JSON.stringify(response.data, null, 2)}`,
      );

      return response.data;
    } catch (error) {
      // Enhanced error logging
      if (error.response) {
        this.logger.error(`❌ Billplz API Error (${error.response.status}):`, {
          status: error.response.status,
          statusText: error.response.statusText,
          data: error.response.data,
          headers: error.response.headers,
        });

        // Provide user-friendly error messages
        if (error.response.status === 401) {
          throw new UnauthorizedException(
            'Billplz authentication failed. Please check BILLPLZ_API_KEY is correct.',
          );
        } else if (error.response.status === 400) {
          const errorMsg =
            error.response.data?.error?.message ||
            JSON.stringify(error.response.data) ||
            'Invalid request';
          throw new BadRequestException(
            `Billplz rejected the payment request: ${errorMsg}`,
          );
        }
      } else if (error.request) {
        this.logger.error('❌ No response from Billplz API:', error.message);
        throw new ServiceUnavailableException(
          'Cannot connect to Billplz. Please check your internet connection.',
        );
      } else {
        this.logger.error('❌ Error creating Billplz bill:', error.message);
      }

      throw error;
    }
  }

  verifyXSignature(payload: BillplzPayload, signature: string): boolean {
    if (!this.signatureKey) {
      this.logger.warn(
        'BILLPLZ_X_SIGNATURE_KEY is not set. Skipping signature verification.',
      );
      return true; // Skip verification if key is missing (dev mode)
    }

    // Billplz X-Signature generation:
    // https://www.billplz.com/api#x-signature
    const sourceString = `amount${payload.amount}|collection_id${payload.collection_id}|due_at${payload.due_at}|email${payload.email}|id${payload.id}|mobile${payload.mobile}|name${payload.name}|paid_amount${payload.paid_amount}|paid_at${payload.paid_at}|paid_at_readable${payload.paid_at_readable}|state${payload.state}|url${payload.url}|x_signature${this.signatureKey}`;

    const generatedSignature = crypto
      .createHmac('sha256', this.signatureKey)
      .update(sourceString)
      .digest('hex');

    return generatedSignature === signature;
  }

  async getBill(billId: string) {
    try {
      if (!this.apiKey) {
        throw new InternalServerErrorException('Billplz API Key is missing.');
      }

      this.logger.log(`🔍 Checking Billplz status for ${billId}`);
      const response = await this.client.get(`/bills/${billId}`);
      return response.data;
    } catch (error) {
      this.logger.error(
        `❌ Error fetching Billplz bill ${billId}:`,
        error.message,
      );
      return null;
    }
  }

  async createPayout(
    bankCode: string,
    bankAccount: string,
    amountInCents: number,
    recipientName: string,
    referenceId: string,
  ) {
    try {
      // Validate required credentials
      if (!this.apiKey) {
        throw new InternalServerErrorException(
          'Billplz API Key is missing for Payout.',
        );
      }

      // Billplz V4 Payout API
      // Documented at https://www.billplz.com/api/v4/payouts
      const payload = {
        currency: 'MYR',
        amount: amountInCents,
        bank_code: bankCode,
        bank_account_number: bankAccount,
        account_holder_name: recipientName,
        reference_id: referenceId, // Usually our own unique ID for tracking
        description: `Payout for ${referenceId}`,
      };

      this.logger.log(
        `💸 Initiating Payout to ${bankCode} (${bankAccount}) - RM${(amountInCents / 100).toFixed(2)}`,
      );
      this.logger.debug(`Payout payload: ${JSON.stringify(payload, null, 2)}`);

      // Using the same axios client but overwriting the URL if needed,
      // or cleaner: just use absolute URL for V4 if base is V3.
      // The client is configured with V3 base URL. We need V4.
      // So we will pass the full URL to override base.

      const isSandbox = this.configService.get('BILLPLZ_SANDBOX') === 'true';
      const payoutUrl = isSandbox
        ? 'https://www.billplz-sandbox.com/api/v4/payouts'
        : 'https://www.billplz.com/api/v4/payouts';

      const response = await this.client.post(payoutUrl, payload);

      this.logger.log(
        `✅ Payout created successfully - ID: ${response.data.id}`,
      );
      this.logger.debug(
        `Payout response: ${JSON.stringify(response.data, null, 2)}`,
      );

      return response.data;
    } catch (error) {
      if (error.response) {
        this.logger.error(
          `❌ Billplz Payout Error (${error.response.status}):`,
          error.response.data,
        );
        throw new BadRequestException(
          `Payout failed: ${JSON.stringify(error.response.data)}`,
        );
      }
      this.logger.error('❌ Error creating payout:', error.message);
      throw error;
    }
  }
}
