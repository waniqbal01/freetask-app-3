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
  Logger,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { UploadsService } from './uploads.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Response } from 'express';
import { UploadsMulterExceptionFilter } from './uploads.filter';
import { ApiBearerAuth, ApiTags, ApiUnauthorizedResponse } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';

@ApiBearerAuth()
@ApiTags('uploads')
@Controller('uploads')
export class UploadsController {
  private readonly logger = new Logger(UploadsController.name);

  constructor(private readonly uploadsService: UploadsService) { }

  @Post()
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 5, ttl: 60000 } }) // Stricter limit for uploads: 5 per minute
  @UseFilters(UploadsMulterExceptionFilter)
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
          const uploadsDir = process.env.UPLOAD_DIR || 'uploads';
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
  uploadFile(@UploadedFile() file: any, @Req() req: any) {
    if (!file) {
      this.logger.warn(`Upload failed: No file provided by user ${req.user?.userId}`);
      throw new BadRequestException('Tiada fail dihantar');
    }

    this.logger.log(
      `File uploaded successfully: ${file.filename} (${file.size} bytes) by user ${req.user?.userId}`,
    );

    return this.uploadsService.buildUploadResponse(file.filename);
  }

  // Public endpoint for serving avatars and public images (no JWT required)
  // Only allows access to UUID-pattern image files for security
  @Get('public/:filename')
  async getPublicFile(@Param('filename') filename: string, @Res({ passthrough: true }) res: Response) {
    const { stream, mimeType, filename: safeName, asAttachment } = await this.uploadsService.getPublicFileStream(filename);
    res.setHeader('Content-Type', mimeType);
    const dispositionType = asAttachment ? 'attachment' : 'inline';
    res.setHeader('Content-Disposition', `${dispositionType}; filename="${safeName}"`);
    return new StreamableFile(stream);
  }

  // Protected endpoint for authenticated users
  @UseGuards(JwtAuthGuard)
  @Get(':filename')
  @ApiUnauthorizedResponse({ description: 'Unauthorized - JWT diperlukan untuk muat turun.' })
  async downloadFile(@Param('filename') filename: string, @Res({ passthrough: true }) res: Response) {
    const { stream, mimeType, filename: safeName, asAttachment } = await this.uploadsService.getFileStream(filename);
    res.setHeader('Content-Type', mimeType);
    const dispositionType = asAttachment ? 'attachment' : 'inline';
    res.setHeader('Content-Disposition', `${dispositionType}; filename="${safeName}"`);
    return new StreamableFile(stream);
  }
}
