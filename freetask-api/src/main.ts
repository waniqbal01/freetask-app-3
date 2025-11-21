import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { join } from 'path';

// ---------------------------------------------------
// Build Allowed CORS Origins (default + .env)
// ---------------------------------------------------
function buildAllowedOrigins(): string[] {
  const defaultOrigins = [
    'http://localhost:3000',   // Next.js local
    'http://localhost:4000',   // API local
    'http://10.0.2.2:4000',    // Android emulator → backend
    'http://localhost:5173',   // Flutter Web (Vite / fixed port)
    'http://127.0.0.1:5173',   // Flutter Web alternative
  ];

  const envOrigins = (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  return Array.from(new Set([...defaultOrigins, ...envOrigins]));
}

// ---------------------------------------------------
// Bootstrap NestJS App (Dev mode = open CORS)
// ---------------------------------------------------
async function bootstrap() {
  try {
    const app = await NestFactory.create(AppModule, {
      bufferLogs: true,
    });

    // ------------------------------
    // CORS Config (Dev = ALL origins)
    // ------------------------------
    const isDev = process.env.NODE_ENV !== 'production';
    const allowedOrigins = buildAllowedOrigins();

    app.enableCors({
      origin: isDev ? true : allowedOrigins,
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    });

    // ------------------------------
    // Global Validation Pipes
    // ------------------------------
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );

    // ------------------------------
    // Serve static uploaded files
    // ------------------------------
    app.useStaticAssets(join(process.cwd(), 'uploads'));

    // ------------------------------
    // Start server
    // ------------------------------
    const port = process.env.PORT || 4000;
    await app.listen(port);

    console.log(`🚀 Application running at: ${await app.getUrl()}`);
    console.log(`🌐 CORS mode: ${isDev ? 'DEV (ALL origins allowed)' : 'PRODUCTION'}`);
    console.log('Allowed Origins (Production Only):', allowedOrigins);

  } catch (error) {
    console.error('❌ Failed to bootstrap application.', error);
    process.exit(1);
  }
}

bootstrap();
