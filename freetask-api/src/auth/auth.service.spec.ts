import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AuthService', () => {
  let service: AuthService;
  let prisma: {
    user: {
      findUnique: jest.Mock;
      create: jest.Mock;
    };
  };
  let jwt: JwtService;

  const baseUser = {
    id: 1,
    email: 'client@freetask.test',
    password: 'hashed',
    name: 'Client One',
    role: UserRole.CLIENT,
  } as const;

  beforeEach(() => {
    prisma = {
      user: {
        findUnique: jest.fn(),
        create: jest.fn(),
      },
    };

    jwt = {
      signAsync: jest.fn().mockResolvedValue('token'),
    } as unknown as JwtService;

    service = new AuthService(prisma as unknown as PrismaService, jwt);
  });

  it('registers a brand new client and returns token + user', async () => {
    prisma.user.findUnique.mockResolvedValue(null);
    prisma.user.create.mockResolvedValue({ ...baseUser });
    jest.spyOn(bcrypt, 'hash').mockResolvedValue('hashed');

    const result = await service.register({
      email: baseUser.email,
      password: 'secret123',
      name: baseUser.name,
      role: UserRole.CLIENT,
    } as any);

    expect(result.accessToken).toBe('token');
    expect(result.user.email).toBe(baseUser.email);
    expect(prisma.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ role: UserRole.CLIENT }),
      }),
    );
  });

  it('throws conflict when registering duplicate email', async () => {
    prisma.user.findUnique.mockResolvedValue(baseUser);

    await expect(
      service.register({
        email: baseUser.email,
        password: 'secret123',
        name: baseUser.name,
        role: UserRole.CLIENT,
      } as any),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('logs in with correct credentials', async () => {
    prisma.user.findUnique.mockResolvedValue(baseUser);
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(true);

    const result = await service.login({
      email: baseUser.email,
      password: 'secret123',
    });

    expect(result.user.email).toBe(baseUser.email);
    expect(jwt.signAsync).toHaveBeenCalledWith({ sub: baseUser.id, role: baseUser.role });
  });

  it('rejects invalid password', async () => {
    prisma.user.findUnique.mockResolvedValue(baseUser);
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(false);

    await expect(
      service.login({
        email: baseUser.email,
        password: 'wrong',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
