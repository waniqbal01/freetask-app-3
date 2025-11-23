import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
} from '@nestjs/common';
import { Response } from 'express';
import {
  JsonWebTokenError,
  NotBeforeError,
  TokenExpiredError,
} from 'jsonwebtoken';

@Catch(JsonWebTokenError)
export class JwtExceptionFilter implements ExceptionFilter<JsonWebTokenError> {
  catch(exception: JsonWebTokenError, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const status = 401;
    const code = exception instanceof TokenExpiredError
      ? 'TOKEN_EXPIRED'
      : exception instanceof NotBeforeError
      ? 'TOKEN_NOT_ACTIVE'
      : 'JWT_INVALID';

    response.status(status).json({
      statusCode: status,
      message: exception.message || 'Invalid token',
      code,
    });
  }
}
