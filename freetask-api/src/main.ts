import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { join } from 'path';
import { JwtExceptionFilter } from './common/filters/jwt-exception.filter';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { getAllowedOrigins, normalizeOrigin } from './config/cors';

// ---------------------------------------------------
// Bootstrap NestJS App (Dev mode = restricted CORS)
// ---------------------------------------------------
async function bootstrap() {
  const logger = new Logger('Bootstrap');
  try {
    if (!process.env.JWT_SECRET || process.env.JWT_SECRET.trim().length === 0) {
      throw new Error('JWT_SECRET is required to start the API server');
    }

    const app = await NestFactory.create(AppModule, {
      bufferLogs: true,
    });

    if (process.env.TRUST_PROXY === 'true') {
      app.set('trust proxy', 1);
      logger.log('Trust proxy enabled for forwarded headers');
    }
    const isProduction = process.env.NODE_ENV === 'production';
    const configuredOrigins = getAllowedOrigins(logger, isProduction);

    const devFallbackPatterns = [
      /^http:\/\/localhost(?::\d+)?$/,
      /^http:\/\/127\.0\.0\.1(?::\d+)?$/,
      /^http:\/\/10\.0\.2\.2(?::\d+)?$/,
      /^http:\/\/192\.168\.\d+\.\d+(?::\d+)?$/,
    ];

    const allowAllDevFallbacks = configuredOrigins.length === 0 && !isProduction;

    app.enableCors({
      origin: (origin, cb) => {
        if (!origin) return cb(null, true);
        const normalizedOrigin = normalizeOrigin(origin);
        if (configuredOrigins.includes(normalizedOrigin) || configuredOrigins.includes('*')) {
          return cb(null, true);
        }
        if (allowAllDevFallbacks && devFallbackPatterns.some((pattern) => pattern.test(normalizedOrigin))) {
          return cb(null, true);
        }
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
    // Swagger documentation
    // ------------------------------
    const config = new DocumentBuilder()
      .setTitle('Freetask API')
      .setDescription('API docs for Freetask MVP')
      .setVersion('1.0')
      .addBearerAuth()
      .build();

    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api', app, document);

    // ------------------------------
    // Start server
    // ------------------------------
    const port = process.env.PORT || 4000;
    await app.listen(port);

    console.log(`🚀 Application running at: ${await app.getUrl()}`);
    console.log('Allowed Origins:', configuredOrigins);

  } catch (error) {
    console.error('❌ Failed to bootstrap application.', error);
    process.exit(1);
  }
}

bootstrap();
