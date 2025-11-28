import { Logger } from '@nestjs/common';

export function normalizeOrigin(origin: string) {
  return origin.trim().replace(/\/$/, '');
}

export function getAllowedOrigins(
  logger: Logger,
  isProduction: boolean,
  env: NodeJS.ProcessEnv = process.env,
) {
  const configuredOrigins = (env.ALLOWED_ORIGINS || '')
    .split(',')
    .flatMap((o) => o.split(/\s+/))
    .map(normalizeOrigin)
    .filter(Boolean);

  if (configuredOrigins.length > 0) {
    return configuredOrigins;
  }

  if (isProduction) {
    const message =
      'ALLOWED_ORIGINS is required in production. Set a comma-separated list of allowed origins to start the API server.';
    logger.error(message);
    throw new Error(message);
  }

  const publicBase = env.PUBLIC_BASE_URL?.trim();
  if (publicBase) {
    const normalizedBase = normalizeOrigin(publicBase);
    logger.warn(
      `⚠️  ALLOWED_ORIGINS missing. Falling back to PUBLIC_BASE_URL (${normalizedBase}). Set ALLOWED_ORIGINS to lock this down.`,
    );
    return [normalizedBase];
  }

  const warningMessage =
    '⚠️  ALLOWED_ORIGINS missing. Falling back to localhost/loopback patterns. Set ALLOWED_ORIGINS or PUBLIC_BASE_URL to lock down CORS.';
  logger.warn(warningMessage);

  return [
    'http://localhost:4000',
    'http://127.0.0.1:4000',
    'http://localhost:3000',
    'http://localhost:5173',
    'http://10.0.2.2:3000',
    'http://10.0.2.2:4000',
    '*', // Allow all in dev for Flutter/mobile testing
  ];
}
