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
  Logger,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { extname } from 'path';
import { UploadsService } from './uploads.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Response, Request } from 'express';
import { UploadsMulterExceptionFilter } from './uploads.filter';
import {
  ApiBearerAuth,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';

interface RequestWithUser extends Request {
  user: { userId: number };
}

@ApiBearerAuth()
@ApiTags('uploads')
@Controller('uploads')
export class UploadsController {
  private readonly logger = new Logger(UploadsController.name);

  constructor(private readonly uploadsService: UploadsService) { }

  @Post()
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 5, ttl: 60000 } })
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
            new BadRequestException(
              'Jenis fail tidak dibenarkan. Hanya gambar/PDF/DOC.',
            ),
            false,
          );
        }

        cb(null, true);
      },
      storage: memoryStorage(),
    }),
  )
  async uploadFile(
    @UploadedFile() file: Express.Multer.File,
    @Req() req: RequestWithUser,
  ) {
    if (!file) {
      this.logger.warn(
        `Upload failed: No file provided by user ${req.user?.userId}`,
      );
      throw new BadRequestException('Tiada fail dihantar');
    }

    const filename = await this.uploadsService.uploadFile(file);
    const publicUrl = this.uploadsService.getPublicUrl(filename);

    this.logger.log(
      `File uploaded to Supabase: ${filename} by user ${req.user?.userId}`,
    );

    return { key: filename, url: publicUrl };
  }

  @Get('public/:filename')
  async getPublicFile(
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    // Redirect to Supabase public URL
    const url = this.uploadsService.getPublicUrl(filename);
    res.redirect(url);
  }

  // Legacy endpoint support (optional, or redirect)
  @UseGuards(JwtAuthGuard)
  @Get(':filename')
  async downloadFile(
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    // Redirect to Supabase public URL (since we made bucket public)
    const url = this.uploadsService.getPublicUrl(filename);
    res.redirect(url);
  }
}
