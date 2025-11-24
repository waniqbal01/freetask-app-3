import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { mkdirSync, existsSync, createReadStream, statSync } from 'fs';
import { extname, join, basename, normalize, sep } from 'path';
import { randomUUID } from 'crypto';

@Injectable()
export class UploadsService {
  private readonly uploadsDir = normalize(join(process.cwd(), process.env.UPLOAD_DIR ?? 'uploads'));

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
    if (originalName.includes('/') || originalName.includes('\\')) {
      throw new BadRequestException('Invalid filename.');
    }

    const fileExt = UploadsService.sanitizeExtension(extname(originalName));
    if (!UploadsService.isAllowedExtension(fileExt)) {
      throw new BadRequestException('Jenis fail tidak dibenarkan. Hanya gambar/PDF/DOC.');
    }

    const uuid = randomUUID();
    return `${uuid}${fileExt}`;
  }

  getFileStream(rawFilename: string) {
    const safeFilename = this.sanitizeRequestedFile(rawFilename);
    const normalizedPath = this.buildSafePath(safeFilename);

    if (!existsSync(normalizedPath)) {
      throw new NotFoundException('File not found');
    }

    const fileStat = statSync(normalizedPath);
    if (!fileStat.isFile()) {
      throw new NotFoundException('File not found');
    }

    const fileExt = extname(normalizedPath).toLowerCase();
    const mimeType = UploadsService.mimeTypeFromExtension(fileExt);

    return {
      stream: createReadStream(normalizedPath),
      mimeType: mimeType ?? 'application/octet-stream',
      filename: basename(normalizedPath),
    };
  }

  buildUploadResponse(filename: string) {
    const relativePath = this.buildRelativePath(filename);
    return { key: filename, url: relativePath };
  }

  private buildRelativePath(filename: string) {
    return `/uploads/${filename}`;
  }

  private sanitizeRequestedFile(rawFilename: string) {
    if (!rawFilename) {
      throw new BadRequestException('Filename is required');
    }

    const decoded = decodeURIComponent(rawFilename);
    const normalized = decoded.replace(/\\+/g, '/');
    if (normalized.includes('..')) {
      throw new BadRequestException('Invalid file path');
    }

    const base = basename(normalized);
    if (!base || base === '.' || base === '..') {
      throw new BadRequestException('Invalid file path');
    }

    return base;
  }

  private buildSafePath(filename: string) {
    const targetPath = normalize(join(this.uploadsDir, filename));
    if (!targetPath.startsWith(this.uploadsDir + sep)) {
      throw new BadRequestException('Invalid file path');
    }
    return targetPath;
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
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };

    return map[extension.toLowerCase()];
  }

  static isLocalHost(host: string) {
    return (
      /^localhost(:\d+)?$/i.test(host) ||
      /^127\.0\.0\.1(:\d+)?$/.test(host) ||
      /^10\.0\.2\.2(:\d+)?$/.test(host) ||
      /^192\.168\.\d+\.\d+(:\d+)?$/.test(host)
    );
  }

  static isAllowedExtension(extension: string) {
    const normalized = extension.toLowerCase();
    const allowed = ['.jpg', '.jpeg', '.png', '.gif', '.pdf', '.doc', '.docx'];
    return allowed.includes(normalized);
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
