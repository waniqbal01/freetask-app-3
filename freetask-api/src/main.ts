import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { JwtExceptionFilter } from './common/filters/jwt-exception.filter';
import { TransformDecimalInterceptor } from './common/interceptors/transform-decimal.interceptor';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { getAllowedOrigins, normalizeOrigin } from './config/cors';

import { NestExpressApplication } from '@nestjs/platform-express';

// ---------------------------------------------------
// Bootstrap NestJS App (Dev mode = restricted CORS)
// ---------------------------------------------------
async function bootstrap() {
  const logger = new Logger('Bootstrap');
  try {
    if (!process.env.JWT_SECRET || process.env.JWT_SECRET.trim().length === 0) {
      throw new Error('JWT_SECRET is required to start the API server');
    }

    const isProduction = process.env.NODE_ENV === 'production';

    // Validate JWT_REFRESH_EXPIRES_IN in production
    if (isProduction && (!process.env.JWT_REFRESH_EXPIRES_IN || process.env.JWT_REFRESH_EXPIRES_IN.trim().length === 0)) {
      throw new Error('JWT_REFRESH_EXPIRES_IN is required in production to start the API server');
    }

    const app = await NestFactory.create<NestExpressApplication>(AppModule, {
      bufferLogs: true,
    });

    if (process.env.TRUST_PROXY === 'true') {
      app.set('trust proxy', 1);
      logger.log('Trust proxy enabled for forwarded headers');
    }
    const configuredOrigins = getAllowedOrigins(logger, isProduction);

    if (isProduction) {
      if (configuredOrigins.length === 0) {
        throw new Error('ALLOWED_ORIGINS must be configured in production for CORS');
      }
      if (configuredOrigins.includes('*')) {
        throw new Error('ALLOWED_ORIGINS cannot use wildcard * in production');
      }
    }

    const devFallbackPatterns = [
      /^http:\/\/localhost(?::\d+)?$/,
      /^http:\/\/127\.0\.0\.1(?::\d+)?$/,
      /^http:\/\/10\.0\.2\.2(?::\d+)?$/,
      /^http:\/\/192\.168\.\d+\.\d+(?::\d+)?$/,
    ];

    app.enableCors({
      origin: (origin, cb) => {
        if (!origin) return cb(null, true);
        const normalizedOrigin = normalizeOrigin(origin);
        if (configuredOrigins.includes(normalizedOrigin) || configuredOrigins.includes('*')) {
          return cb(null, true);
        }
        if (!isProduction && configuredOrigins.length === 0) {
          if (devFallbackPatterns.some((pattern) => pattern.test(normalizedOrigin))) {
            return cb(null, true);
          }
        }
        if (isProduction && configuredOrigins.length === 0) {
          logger.error(`CORS blocked origin ${origin} because ALLOWED_ORIGINS is empty in production`);
          return cb(new Error(`CORS blocked origin: ${origin}`), false);
        }
        if (devFallbackPatterns.some((pattern) => pattern.test(normalizedOrigin))) {
          return cb(null, true);
        }
        return cb(new Error(`CORS blocked origin: ${origin}`), false);
      },
      credentials: true,
      methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
      allowedHeaders: 'Content-Type, Authorization, X-Signature',
      maxAge: 86400,
    });

    // ------------------------------
    // Initialize Firebase Admin
    // ------------------------------
    try {
      const admin = require('firebase-admin');
      const serviceAccount = process.env.FIREBASE_CREDENTIALS
        ? JSON.parse(process.env.FIREBASE_CREDENTIALS)
        : undefined;

      if (serviceAccount) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
        logger.log('Firebase Admin initialized successfully');
      } else {
        logger.warn('FIREBASE_CREDENTIALS not provided. Push notifications will describe only.');
      }
    } catch (error) {
      logger.error('Failed to initialize Firebase Admin', error);
    }

    // ------------------------------
    // Global Upload Size Limits
    // ------------------------------
    const express = require('express');
    app.use(express.json({ limit: '10mb' }));
    app.use(express.urlencoded({ extended: true, limit: '10mb' }));

    // ------------------------------
    // Global Filters & Interceptors
    // ------------------------------
    app.useGlobalFilters(new JwtExceptionFilter());
    app.useGlobalInterceptors(new TransformDecimalInterceptor());

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
    // Swagger documentation (Dev/Test only)
    // ------------------------------
    if (process.env.NODE_ENV !== 'production') {
      const config = new DocumentBuilder()
        .setTitle('Freetask API')
        .setDescription('API docs for Freetask MVP')
        .setVersion('1.0')
        .addBearerAuth()
        .build();

      const document = SwaggerModule.createDocument(app, config);
      SwaggerModule.setup('api', app, document);
    }

    // ------------------------------
    // Start server
    // ------------------------------
    const port = process.env.PORT || 4000;
    // Bind to 0.0.0.0 for container environments (DigitalOcean, Docker, etc.)
    await app.listen(port, '0.0.0.0');

    console.log(`🚀 Application running at: ${await app.getUrl()}`);
    console.log('Allowed Origins:', configuredOrigins);

  } catch (error) {
    console.error('❌ Failed to bootstrap application.', error);
    process.exit(1);
  }
}

bootstrap();
