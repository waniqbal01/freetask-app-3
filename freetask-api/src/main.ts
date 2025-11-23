import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { join } from 'path';
import { JwtExceptionFilter } from './common/filters/jwt-exception.filter';

// ---------------------------------------------------
// Bootstrap NestJS App (Dev mode = restricted CORS)
// ---------------------------------------------------
async function bootstrap() {
  try {
    const app = await NestFactory.create(AppModule, {
      bufferLogs: true,
    });
    const isProduction = process.env.NODE_ENV === 'production';
    const configuredOrigins = (process.env.ALLOWED_ORIGINS || '')
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean);

    const devFallbackOrigins = [
      'http://localhost:4000',
      'http://127.0.0.1:4000',
      'http://localhost:3000',
      'http://localhost:5173',
      'http://10.0.2.2:4000',
    ];

    const allowedOrigins =
      configuredOrigins.length > 0 || isProduction
        ? configuredOrigins
        : devFallbackOrigins;

    app.enableCors({
      origin: (origin, cb) => {
        if (!origin) return cb(null, true);
        if (allowedOrigins.includes(origin)) return cb(null, true);
        return cb(new Error(`CORS blocked origin: ${origin}`), false);
      },
      credentials: true,
      methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
      allowedHeaders: 'Content-Type, Authorization',
    });

    // ------------------------------
    // Global Filters
    // ------------------------------
    app.useGlobalFilters(new JwtExceptionFilter());

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
    console.log('Allowed Origins:', allowedOrigins);

  } catch (error) {
    console.error('❌ Failed to bootstrap application.', error);
    process.exit(1);
  }
}

bootstrap();
