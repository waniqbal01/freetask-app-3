import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { UserRole } from '@prisma/client';

@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const role: UserRole | undefined = request?.user?.role;

    if (role === UserRole.ADMIN) {
      return true;
    }

    throw new ForbiddenException('Admin access only');
  }
}
