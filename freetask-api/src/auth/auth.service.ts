import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { randomBytes } from 'crypto';
import { User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AuthUser } from './types/auth-user.type';
import { toAppUser } from '../users/user.mapper';
import { RefreshTokenDto } from './dto/refresh-token.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) { }

  private readonly logger = new Logger(AuthService.name);

  private readonly accessTtlMs = this.resolveDuration(
    process.env.JWT_ACCESS_EXPIRES_IN || process.env.JWT_EXPIRES_IN || '30m',
    30 * 60 * 1000,
  );

  private readonly refreshTtlMs = this.resolveDuration(
    process.env.JWT_REFRESH_EXPIRES_IN,
    process.env.NODE_ENV === 'production' ? undefined : 7 * 24 * 60 * 60 * 1000, // 7d default in dev
  );

  async register(
    dto: RegisterDto,
  ): Promise<{ accessToken: string; refreshToken: string; user: AuthUser }> {
    const email = dto.email.toLowerCase();
    const roleRaw = dto.role?.toString().toUpperCase();
    if (!['CLIENT', 'FREELANCER'].includes(roleRaw)) {
      throw new BadRequestException('Role must be CLIENT or FREELANCER');
    }
    dto.role = roleRaw as any;
    const existing = await this.prisma.user.findUnique({
      where: { email },
    });
    if (existing) {
      throw new ConflictException('Email already in use');
    }

    const avatarUrl = dto.avatarUrl;

    const hashed = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: {
        email,
        password: hashed,
        name: dto.name,
        role: dto.role as any,
        avatarUrl,
        bio: dto.bio,
        skills: dto.skills,
        rate: dto.rate,
      },
    });

    return this.buildAuthResponse(user);
  }

  async login(
    dto: LoginDto,
  ): Promise<{ accessToken: string; refreshToken: string; user: AuthUser }> {
    const email = dto.email.toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email },
    });
    if (!user) {
      throw new UnauthorizedException('Email atau password salah');
    }

    const valid = await bcrypt.compare(dto.password, user.password);
    if (!valid) {
      throw new UnauthorizedException('Email atau password salah');
    }

    return this.buildAuthResponse(user);
  }

  async getMe(userId: number): Promise<AuthUser> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) {
      throw new UnauthorizedException();
    }
    return toAppUser(user);
  }

  async refresh(
    dto: RefreshTokenDto,
  ): Promise<{ accessToken: string; refreshToken: string; user: AuthUser }> {
    const { refreshToken } = dto;
    const [sessionIdPart, rawToken] = refreshToken?.split('.') ?? [];
    const sessionId = Number(sessionIdPart);
    if (!sessionId || !rawToken) {
      this.logger.warn(`Refresh failed: Invalid token format (token: ${refreshToken})`);
      throw new UnauthorizedException('Refresh token tidak sah');
    }

    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      include: { user: true },
    });

    if (!session || session.revoked) {
      this.logger.warn(`Refresh failed: Session ${sessionId} not found or revoked`);
      throw new UnauthorizedException('Sesi telah tamat. Sila log masuk semula.');
    }

    if (session.refreshTokenExpiresAt.getTime() < Date.now()) {
      this.logger.warn(`Refresh failed: Session ${sessionId} expired at ${session.refreshTokenExpiresAt}`);
      await this.prisma.session.update({
        where: { id: session.id },
        data: { revoked: true },
      });
      throw new UnauthorizedException('Sesi telah tamat. Sila log masuk semula.');
    }

    const tokenMatches =
      !!session.refreshTokenHash && (await bcrypt.compare(rawToken, session.refreshTokenHash));
    if (!tokenMatches) {
      this.logger.warn(`Refresh failed: Token mismatch for session ${sessionId}`);
      await this.prisma.session.update({
        where: { id: session.id },
        data: { revoked: true },
      });
      throw new UnauthorizedException('Refresh token tidak sah');
    }

    const refreshTokenExpiresAt = new Date(Date.now() + this.refreshTtlMs);
    const nextRawToken = this.generateSecureToken();
    const nextHash = await bcrypt.hash(nextRawToken, 10);

    const updatedSession = await this.prisma.session.update({
      where: { id: session.id },
      data: {
        refreshTokenHash: nextHash,
        refreshTokenExpiresAt,
        revoked: false,
      },
    });

    const nextRefreshToken = `${updatedSession.id}.${nextRawToken}`;
    const accessToken = await this.signAccessToken(session.user, updatedSession.id);

    return {
      accessToken,
      refreshToken: nextRefreshToken,
      user: toAppUser(session.user),
    };
  }

  async logout(userId: number, sessionId?: number) {
    if (!sessionId) {
      await this.prisma.session.updateMany({
        where: { userId },
        data: { revoked: true, refreshTokenHash: null },
      });
      return { message: 'logged out (all sessions revoked)' };
    }

    await this.prisma.session.updateMany({
      where: { id: sessionId, userId },
      data: { revoked: true, refreshTokenHash: null },
    });
    return { message: 'logged out' };
  }

  private async buildAuthResponse(
    user: User,
  ): Promise<{ accessToken: string; refreshToken: string; user: AuthUser }> {
    const refreshTokenExpiresAt = new Date(Date.now() + this.refreshTtlMs);
    const rawRefreshToken = this.generateSecureToken();
    const refreshHash = await bcrypt.hash(rawRefreshToken, 10);

    const session = await this.prisma.session.create({
      data: {
        userId: user.id,
        refreshTokenHash: refreshHash,
        refreshTokenExpiresAt,
      },
    });

    const refreshToken = `${session.id}.${rawRefreshToken}`;
    const accessToken = await this.signAccessToken(user, session.id);
    return {
      accessToken,
      refreshToken,
      user: toAppUser(user),
    };
  }

  private async signAccessToken(user: User, sessionId: number) {
    const payload = { sub: user.id, role: user.role, sid: sessionId };
    return this.jwtService.signAsync(payload, {
      expiresIn: Math.floor(this.accessTtlMs / 1000),
    });
  }

  private resolveDuration(input: string | undefined, fallbackMs: number | undefined): number {
    if (!input) {
      if (fallbackMs === undefined) {
        throw new Error('JWT configuration missing: Explicit expiry required');
      }
      return fallbackMs;
    }
    const match = input.match(/^(\d+)([smhdw])?$/i);
    if (!match) {
      if (fallbackMs === undefined) {
        throw new Error(`Invalid JWT expiry format: ${input}`);
      }
      return fallbackMs;
    }
    const value = Number(match[1]);
    const unit = (match[2] || 'ms').toLowerCase();
    const factor: Record<string, number> = {
      ms: 1,
      s: 1000,
      m: 60 * 1000,
      h: 60 * 60 * 1000,
      d: 24 * 60 * 60 * 1000,
      w: 7 * 24 * 60 * 60 * 1000,
    };
    return value * (factor[unit] || 1);
  }

  private generateSecureToken() {
    return randomBytes(48).toString('hex');
  }
}
