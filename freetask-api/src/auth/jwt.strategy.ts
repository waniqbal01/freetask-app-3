import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET,
    });
  }

  async validate(payload: { sub: number; role: string; sid?: number }) {
    if (!payload.sid) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'SID_MISSING',
        message: 'Session tidak sah',
      });
    }

    const session = await this.prisma.session.findUnique({ where: { id: payload.sid } });

    if (!session || session.revoked || session.refreshTokenExpiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException('Sesi telah tamat. Sila log masuk semula.');
    }

    return { id: payload.sub, userId: payload.sub, role: payload.role, sessionId: payload.sid };
  }
}
