import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { Request } from 'express';
import { mkdirSync, existsSync } from 'fs';
import { extname, join, basename } from 'path';

@Injectable()
export class UploadsService {
  private readonly uploadsDir = join(process.cwd(), 'uploads');

  ensureUploadsDir() {
    if (!existsSync(this.uploadsDir)) {
      try {
        mkdirSync(this.uploadsDir, { recursive: true });
      } catch (error) {
        throw new InternalServerErrorException('Upload directory not writable');
      }
    }
  }

  getUploadsDir() {
    return this.uploadsDir;
  }

  buildFileName(originalName: string) {
    const sanitizedName = UploadsService.sanitizeBaseName(originalName);
    const fileExt = UploadsService.sanitizeExtension(extname(originalName));
    const timestamp = Date.now();

    return `${sanitizedName}-${timestamp}${fileExt}`;
  }

  buildFileUrl(request: Request, filename: string) {
    const forwardedProto = request.get('x-forwarded-proto');
    const forwardedHost = request.get('x-forwarded-host');
    const configuredBase = process.env.PUBLIC_BASE_URL?.trim();

    const host = forwardedHost || request.get('host');
    const protocol = forwardedProto || request.protocol;
    const origin = configuredBase || `${protocol}://${host}`;

    const sanitizedOrigin = origin.endsWith('/') ? origin.slice(0, -1) : origin;
    return `${sanitizedOrigin}/uploads/${filename}`;
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

  static sanitizeBaseName(originalName: string) {
    const normalized = basename(originalName).replace(/[/\\]+/g, '');
    const base = normalized.replace(extname(normalized), '').replace(/\s+/g, '-');
    const safe = base.replace(/[^a-zA-Z0-9-_]/g, '');
    return safe.length === 0 ? 'file' : safe;
  }

  static sanitizeExtension(extension: string) {
    const normalized = extension.replace(/[^a-zA-Z0-9.]/g, '');
    if (!normalized.startsWith('.')) {
      return normalized ? `.${normalized}` : '';
    }
    return normalized;
  }
}
