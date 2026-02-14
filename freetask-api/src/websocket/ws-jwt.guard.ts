import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Socket } from 'socket.io';

@Injectable()
export class WsJwtGuard implements CanActivate {
  private readonly logger = new Logger(WsJwtGuard.name);

  constructor(private readonly jwtService: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    try {
      const client: Socket & { userId?: number; userName?: string } = context
        .switchToWs()
        .getClient();

      // Extract token from handshake headers
      const token = this.extractTokenFromHandshake(client);

      if (!token) {
        this.logger.warn('No token provided in WebSocket handshake');
        return false;
      }

      // Verify and decode token
      const payload = await this.jwtService.verifyAsync(token, {
        secret: process.env.JWT_SECRET,
      });

      // Attach user info to socket
      client.userId = payload.userId;
      client.userName = payload.name || 'Unknown';

      return true;
    } catch (error) {
      this.logger.error(`WebSocket authentication failed: ${error.message}`);
      return false;
    }
  }

  private extractTokenFromHandshake(client: Socket): string | null {
    // Try to get token from Authorization header
    const authHeader = client.handshake.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }

    // Try to get from query params (fallback)
    const token = client.handshake.auth?.token || client.handshake.query?.token;
    return token ? String(token) : null;
  }
}
