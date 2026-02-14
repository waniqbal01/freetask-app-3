import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  UnauthorizedException,
} from '@nestjs/common';
import { Response } from 'express';
import {
  JsonWebTokenError,
  NotBeforeError,
  TokenExpiredError,
} from 'jsonwebtoken';

@Catch(JsonWebTokenError, UnauthorizedException)
export class JwtExceptionFilter implements ExceptionFilter<
  JsonWebTokenError | UnauthorizedException
> {
  catch(
    exception: JsonWebTokenError | UnauthorizedException,
    host: ArgumentsHost,
  ) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const status = 401;

    if (exception instanceof UnauthorizedException) {
      const payload = exception.getResponse();
      const data =
        typeof payload === 'string'
          ? { message: payload }
          : (payload as Record<string, unknown>);

      response.status(status).json({
        statusCode: status,
        message:
          (data?.message as string) || exception.message || 'Unauthorized',
        code: data?.code ?? 'UNAUTHORIZED',
      });
      return;
    }

    const code =
      exception instanceof TokenExpiredError
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
