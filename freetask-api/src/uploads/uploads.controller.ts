import {
  BadRequestException,
  Controller,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
  Req,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { Request } from 'express';
import { extname } from 'path';
import { UploadsService } from './uploads.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) {}

  @Post()
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
          this.uploadsService.ensureUploadsDir();
          cb(null, this.uploadsService.getUploadsDir());
        },
        filename: (_req, file, cb) => {
          const filename = this.uploadsService.buildFileName(file.originalname);
          cb(null, filename);
        },
      }),
    }),
  )
  uploadFile(@UploadedFile() file: Express.Multer.File, @Req() request: Request) {
    return { url: this.uploadsService.buildFileUrl(request, file.filename) };
  }
}
