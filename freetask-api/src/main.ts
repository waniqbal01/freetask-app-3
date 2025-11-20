import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { join } from 'path';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';

// ---------------------------------------------------
// Build Allowed CORS Origins (default + .env variable)
// ---------------------------------------------------
function buildAllowedOrigins(): string[] {
  const defaultOrigins = [
    'http://localhost:3000',   // Next.js local
    'http://localhost:4000',   // API local
    'http://10.0.2.2:4000',    // Android emulator → backend
    'http://localhost:5173',   // Flutter Web (Vite)
    'http://127.0.0.1:5173',   // Flutter Web alternative
  ];

  const envOrigins = (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  return Array.from(new Set([...defaultOrigins, ...envOrigins]));
}

// ---------------------------------------------------
// Bootstrap the NestJS App (Recommended Style)
// ---------------------------------------------------
async function bootstrap() {
  try {
    const app = await NestFactory.create(AppModule, {
      bufferLogs: true,
    });

    // ------------------------------
    // CORS Configuration
    // ------------------------------
    // Add extra origins by setting ALLOWED_ORIGINS="http://localhost:3001,http://mydemo" in .env.
    const allowedOrigins = buildAllowedOrigins();

    app.enableCors({
      origin: allowedOrigins,
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    });

    // ------------------------------
    // Global Pipes
    // ------------------------------
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );

    // ------------------------------
    // Request Logging
    // ------------------------------
    app.useGlobalInterceptors(new LoggingInterceptor());

    // ------------------------------
    // Swagger / OpenAPI
    // ------------------------------
    const swaggerConfig = new DocumentBuilder()
      .setTitle('Freetask API')
      .setDescription(
        'REST API powering the Freetask marketplace for clients and freelancers.',
      )
      .setVersion('1.0.0')
      .addBearerAuth()
      .build();

    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);

    // ------------------------------
    // Static File Serving (uploads)
    // ------------------------------
    app.useStaticAssets(join(process.cwd(), 'uploads'));

    // ------------------------------
    // Start Server
    // ------------------------------
    const port = process.env.PORT || 4000;
    await app.listen(port);

    console.log(`🚀 Application running at: ${await app.getUrl()}`);
    console.log('Allowed CORS Origins:', allowedOrigins);
  } catch (error) {
    console.error(
      '❌ Failed to bootstrap application. Check DATABASE_URL & connection.',
      error,
    );
    process.exit(1);
  }
}

bootstrap();
