import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { mkdirSync, existsSync, createReadStream, statSync } from 'fs';
import { extname, join, basename, normalize, sep } from 'path';
import { randomUUID } from 'crypto';
import { SupabaseClient, createClient } from '@supabase/supabase-js';

@Injectable()
export class UploadsService {
  private supabase: SupabaseClient;
  private readonly bucketName = process.env.SUPABASE_BUCKET || 'uploads';
  private readonly logger = new Logger(UploadsService.name);

  constructor() {
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_KEY;

    if (!supabaseUrl || !supabaseKey) {
      this.logger.warn(
        'Supabase credentials missing. Uploads will fail until configured.',
      );
    }

    this.supabase = createClient(supabaseUrl ?? '', supabaseKey ?? '');
  }

  async uploadFile(file: Express.Multer.File): Promise<string> {
    const fileExt = extname(file.originalname);
    const fileName = `${randomUUID()}${fileExt}`;
    const filePath = `${fileName}`;

    const { data, error } = await this.supabase.storage
      .from(this.bucketName)
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });

    if (error) {
      this.logger.error(`Supabase upload failed: ${error.message}`);
      throw new InternalServerErrorException('Gagal memuat naik fail.');
    }

    return fileName;
  }

  getPublicUrl(filename: string): string {
    const { data } = this.supabase.storage
      .from(this.bucketName)
      .getPublicUrl(filename);

    return data.publicUrl;
  }

  static isAllowedMimeType(mimeType?: string | null) {
    if (!mimeType) {
      return false;
    }

    const allowed = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ];

    return allowed.includes(mimeType.toLowerCase());
  }

  static mimeTypeFromExtension(extension: string) {
    const map: Record<string, string> = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };

    return map[extension.toLowerCase()];
  }

  static isAllowedExtension(extension: string) {
    const normalized = extension.toLowerCase();
    const allowed = ['.jpg', '.jpeg', '.png', '.gif', '.pdf', '.doc', '.docx'];
    return allowed.includes(normalized);
  }

  static isPublicFile(filename: string): boolean {
    if (
      !filename ||
      filename.includes('..') ||
      filename.includes('/') ||
      filename.includes('\\')
    ) {
      return false;
    }

    // Relaxed UUID pattern to avoid version/variant mismatches
    const uuidPattern = /^[0-9a-fA-F-]+\.(jpg|jpeg|png|gif)$/i;
    return uuidPattern.test(filename);
  }
}
