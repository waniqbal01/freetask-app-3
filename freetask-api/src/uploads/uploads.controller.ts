import {
  BadRequestException,
  Controller,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { Request } from 'express';
import { UploadsService } from './uploads.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('Uploads')
@ApiBearerAuth()
@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) {}

  @ApiOperation({ summary: 'Upload a file (images or PDF)' })
  @ApiConsumes('multipart/form-data')
  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      fileFilter: (_req, file, cb) => {
        const allowedMimeTypes = ['image/png', 'image/jpeg', 'application/pdf'];
        if (!allowedMimeTypes.includes(file.mimetype)) {
          return cb(
            new BadRequestException('Fail mesti dalam format PNG, JPEG, atau PDF'),
            false,
          );
        }
        cb(null, true);
      },
      limits: {
        fileSize: 10 * 1024 * 1024, // 10MB
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
