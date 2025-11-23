import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import { Request } from 'express';
import { mkdirSync, existsSync } from 'fs';
import { extname, join, basename } from 'path';

@Injectable()
export class UploadsService {
  private readonly uploadsDir = join(process.cwd(), 'uploads');
  private warnedMissingBaseUrl = false;

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
    const configuredBase = process.env.PUBLIC_BASE_URL?.trim();
    const trustProxy = process.env.TRUST_PROXY === 'true';
    const strictBaseCheck = process.env.PUBLIC_BASE_URL_STRICT !== 'false';
    const forwardedProto = request.get('x-forwarded-proto');
    const forwardedHost = request.get('x-forwarded-host');
    const host = trustProxy ? forwardedHost || request.get('host') : request.get('host');
    const protocol = trustProxy ? forwardedProto || request.protocol : request.protocol;

    if (configuredBase) {
      const normalized = UploadsService.normalizeBaseUrl(configuredBase);
      if (strictBaseCheck && host && !UploadsService.hostMatches(normalized, host)) {
        throw new BadRequestException(
          'PUBLIC_BASE_URL is enforced and does not match the incoming host.',
        );
      }
      return `${normalized}/uploads/${filename}`;
    }

    if (!host) {
      throw new InternalServerErrorException('Unable to determine request host for upload URL');
    }

    if (!this.warnedMissingBaseUrl && process.env.NODE_ENV !== 'production') {
      this.warnedMissingBaseUrl = true;
      // eslint-disable-next-line no-console
      console.warn(
        '⚠️  PUBLIC_BASE_URL not set; falling back to request host headers. Set PUBLIC_BASE_URL to avoid forged URLs.',
      );
    }

    const origin = `${protocol}://${host}`;
    const sanitizedOrigin = UploadsService.normalizeBaseUrl(origin);
    return `${sanitizedOrigin}/uploads/${filename}`;
  }

  static normalizeBaseUrl(origin: string) {
    return origin.endsWith('/') ? origin.slice(0, -1) : origin;
  }

  static hostMatches(baseUrl: string, requestHost: string) {
    try {
      const parsed = new URL(baseUrl);
      return parsed.host === requestHost;
    } catch (_) {
      return false;
    }
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
