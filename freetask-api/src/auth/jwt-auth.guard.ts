import { Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  handleRequest(err: unknown, user: any, info: unknown) {
    if (err || !user) {
      throw new UnauthorizedException(
        'Sila log masuk untuk meneruskan permintaan.',
      );
    }
    return user;
  }
}
