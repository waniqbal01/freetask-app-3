import {
  BadRequestException,
  Controller,
  Get,
  Param,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
  Req,
  Res,
  UseFilters,
  StreamableFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { UploadsService } from './uploads.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Response } from 'express';
import { UploadsMulterExceptionFilter } from './uploads.filter';

@Controller('uploads')
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) { }

  @Post()
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        if (!file) {
          return cb(new BadRequestException('Tiada fail dihantar'), false);
        }

        if (!UploadsService.isAllowedMimeType(file.mimetype)) {
          return cb(
            new BadRequestException(
              'Fail tidak disokong. Hanya imej dan dokumen PDF/DOC dibenarkan.',
            ),
            false,
          );
        }

        const fileExt = extname(file.originalname || '').toLowerCase();
        if (!UploadsService.isAllowedExtension(fileExt)) {
          return cb(
            new BadRequestException('Jenis fail tidak dibenarkan. Hanya gambar/PDF/DOC.'),
            false,
          );
        }

        cb(null, true);
      },
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          const uploadsDir = 'uploads'; // Default fallback
          if (!require('fs').existsSync(uploadsDir)) {
            require('fs').mkdirSync(uploadsDir, { recursive: true });
          }
          cb(null, uploadsDir);
        },
        filename: (_req, file, cb) => {
          const { extname } = require('path');
          const { randomUUID } = require('crypto');
          const fileExt = extname(file.originalname || '').toLowerCase();
          // Simple sanitization for extension
          const safeExt = fileExt.replace(/[^a-z0-9.]/g, '');
          const filename = `${randomUUID()}${safeExt}`;
          cb(null, filename);
        },
      }),
    }),
  )
  uploadFile(@UploadedFile() file: any) {
    if (!file) {
      throw new BadRequestException('Tiada fail dihantar');
    }

    return this.uploadsService.buildUploadResponse(file.filename);
  }

  @Get(':filename')
  async downloadFile(@Param('filename') filename: string, @Res({ passthrough: true }) res: Response) {
    const { stream, mimeType, filename: safeName, asAttachment } = await this.uploadsService.getFileStream(filename);
    res.setHeader('Content-Type', mimeType);
    const dispositionType = asAttachment ? 'attachment' : 'inline';
    res.setHeader('Content-Disposition', `${dispositionType}; filename="${safeName}"`);
    return new StreamableFile(stream);
  }
}
