import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { join } from 'path';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';

// ---------------------------------------------------
// Build Allowed CORS Origins (default + .env variable)
// ---------------------------------------------------
function normalizeOrigin(origin?: string | null): string | undefined {
  if (!origin) return undefined;
  try {
    // Use URL API to strip trailing paths/query and return origin only.
    const parsed = new URL(origin);
    return parsed.origin;
  } catch (error) {
    // Fallback to trimming whitespace and trailing slashes for simple host strings.
    return origin.trim().replace(/\/$/, '') || undefined;
  }
}

function buildAllowedOrigins(): string[] {
  const defaultOrigins = [
    'http://localhost:3000', // Next.js local
    'http://localhost:4000', // API local
    'http://10.0.2.2:4000', // Android emulator → backend
    'http://localhost:5173', // Flutter Web (Vite)
    'http://127.0.0.1:5173', // Flutter Web alternative
  ];

  const envOrigins = (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => normalizeOrigin(origin))
    .filter((origin): origin is string => Boolean(origin));

  const appUrl = normalizeOrigin(process.env.APP_URL);

  return Array.from(new Set([...defaultOrigins, ...envOrigins, appUrl].filter(Boolean)));
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
    const corsOptions: CorsOptions = {
      origin: (origin, callback) => {
        const normalizedOrigin = normalizeOrigin(origin);
        if (!normalizedOrigin) {
          // Allow server-to-server or mobile app requests without Origin header.
          return callback(null, true);
        }
        if (allowedOrigins.includes('*') || allowedOrigins.includes(normalizedOrigin)) {
          return callback(null, true);
        }
        return callback(new Error(`Origin not allowed by CORS: ${normalizedOrigin}`));
      },
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      optionsSuccessStatus: 204,
    };

    app.enableCors(corsOptions);

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
    const host = process.env.HOST || '0.0.0.0';
    await app.listen(port, host);

    console.log(`🚀 Application running at: ${await app.getUrl()}`);
    console.log('Allowed CORS Origins:', allowedOrigins);
    console.log(`Listening on host ${host} and port ${port}`);
  } catch (error) {
    console.error(
      '❌ Failed to bootstrap application. Check DATABASE_URL & connection.',
      error,
    );
    process.exit(1);
  }
}

bootstrap();
