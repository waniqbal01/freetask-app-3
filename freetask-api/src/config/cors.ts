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

  const publicBase = env.PUBLIC_BASE_URL?.trim();
  if (publicBase) {
    const normalizedBase = normalizeOrigin(publicBase);
    logger.warn(
      `⚠️  ALLOWED_ORIGINS missing. Falling back to PUBLIC_BASE_URL (${normalizedBase}). Set ALLOWED_ORIGINS to lock this down.`,
    );
    return [normalizedBase];
  }

  if (isProduction) {
    const message =
      'ALLOWED_ORIGINS and PUBLIC_BASE_URL are required in production. Set ALLOWED_ORIGINS="https://app.freetask.my,https://admin.freetask.my" or PUBLIC_BASE_URL="https://app.freetask.my" before starting the server.';
    logger.error(`🚫 ${message}`);
    throw new Error(message);
  }

  logger.warn(
    '⚠️  ALLOWED_ORIGINS missing. Allowing common localhost origins for development only. Set ALLOWED_ORIGINS to secure.',
  );

  return [
    'http://localhost:4000',
    'http://127.0.0.1:4000',
    'http://localhost:3000',
    'http://localhost:5173',
    'http://10.0.2.2:3000',
    'http://10.0.2.2:4000',
  ];
}
