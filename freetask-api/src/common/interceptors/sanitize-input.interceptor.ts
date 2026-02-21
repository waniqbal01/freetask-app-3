import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import * as sanitizeHtml from 'sanitize-html';

@Injectable()
export class SanitizeInputInterceptor implements NestInterceptor {
  // Fields to exclude from sanitization (e.g. passwords, tokens)
  private readonly excludedFields = [
    'password',
    'confirmPassword',
    'oldPassword',
    'newPassword',
    'token',
    'refreshToken',
  ];

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();

    if (request.body) {
      request.body = this.sanitizeItem(request.body);
    }
    if (request.query) {
      request.query = this.sanitizeItem(request.query);
    }
    if (request.params) {
      request.params = this.sanitizeItem(request.params);
    }

    return next.handle();
  }

  private sanitizeItem(item: any, key?: string): any {
    // If the key is in the exclusion list, return the value as-is
    if (key && this.excludedFields.includes(key)) {
      return item;
    }

    // Handle strings: sanitize them
    if (typeof item === 'string') {
      return sanitizeHtml(item, {
        allowedTags: [],
        allowedAttributes: {},
        disallowedTagsMode: 'discard',
      });
    }

    // Handle arrays: sanitize each element recursively
    if (Array.isArray(item)) {
      return item.map((element) => this.sanitizeItem(element));
    }

    // Handle objects: sanitize each property recursively
    if (item !== null && typeof item === 'object') {
      const sanitizedObj: any = {};
      for (const objKey in item) {
        if (Object.prototype.hasOwnProperty.call(item, objKey)) {
          sanitizedObj[objKey] = this.sanitizeItem(item[objKey], objKey);
        }
      }
      return sanitizedObj;
    }

    // Return other types as-is (numbers, booleans, null, undefined)
    return item;
  }
}
