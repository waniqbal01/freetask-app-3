import {
  ArgumentsHost,
  BadRequestException,
  Catch,
  ExceptionFilter,
} from '@nestjs/common';
import { MulterError } from 'multer';

@Catch(MulterError)
export class UploadsMulterExceptionFilter implements ExceptionFilter {
  catch(exception: MulterError, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse();

    const message =
      exception.code === 'LIMIT_FILE_SIZE'
        ? 'Fail melebihi had maksimum 5MB.'
        : exception.message || 'Muat naik fail gagal.';

    const error = new BadRequestException(message);
    const resBody = error.getResponse();
    const status = error.getStatus();

    response.status(status).json(resBody);
  }
}
