import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const method: string = request?.method ?? 'UNKNOWN';
    const url: string = request?.url ?? 'unknown';
    const startTime = Date.now();

    return next.handle().pipe(
      tap(() => {
        const response = context.switchToHttp().getResponse();
        const statusCode: number = response?.statusCode ?? 0;
        const responseTime = Date.now() - startTime;
        this.logger.log(`${method} ${url} ${statusCode} - ${responseTime}ms`);
      }),
    );
  }
}
