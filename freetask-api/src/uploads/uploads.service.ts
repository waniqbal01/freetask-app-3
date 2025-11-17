import { Injectable } from '@nestjs/common';
import { Request } from 'express';
import { mkdirSync, existsSync } from 'fs';
import { extname, join, basename } from 'path';

@Injectable()
export class UploadsService {
  private readonly uploadsDir = join(process.cwd(), 'uploads');

  ensureUploadsDir() {
    if (!existsSync(this.uploadsDir)) {
      mkdirSync(this.uploadsDir, { recursive: true });
    }
  }

  getUploadsDir() {
    return this.uploadsDir;
  }

  buildFileName(originalName: string) {
    const fileExt = extname(originalName);
    const nameWithoutExt = basename(originalName, fileExt).replace(/\s+/g, '-');
    const timestamp = Date.now();

    return `${nameWithoutExt}-${timestamp}${fileExt}`;
  }

  buildFileUrl(request: Request, filename: string) {
    const host = request.get('host');
    const protocol = request.protocol;

    return `${protocol}://${host}/uploads/${filename}`;
  }
}
