import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { join } from 'path';

function buildAllowedOrigins(): string[] {
  const defaultOrigins = [
    'http://localhost:3000',
    'http://localhost:4000',
    'http://10.0.2.2:4000',
    'http://localhost:5173',
    'http://127.0.0.1:5173',
  ];

  const envOrigins = (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  // Use Set to avoid duplicates while keeping the default origins intact.
  return Array.from(new Set([...defaultOrigins, ...envOrigins]));
}

async function bootstrap() {
  try {
    const app = await NestFactory.create(AppModule, {
      bufferLogs: true,
    });

    app.enableCors({
      origin: buildAllowedOrigins(),
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    });
    // To allow new dev origins, set ALLOWED_ORIGINS (comma separated) or append to buildAllowedOrigins default list.

    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );

    app.useStaticAssets(join(process.cwd(), 'uploads'));

    // Default to port 4000 so the backend aligns with the Flutter client configuration.
    const port = process.env.PORT || 4000;
    await app.listen(port);
    console.log(`Application is running on: ${await app.getUrl()}`);
  } catch (error) {
    console.error(
      'Failed to bootstrap application. Ensure DATABASE_URL is valid and the database is reachable before starting the server.',
      error,
    );
    process.exit(1);
  }
}

bootstrap();
