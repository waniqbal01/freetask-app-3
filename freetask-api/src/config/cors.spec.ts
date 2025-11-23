import { Logger } from '@nestjs/common';
import { getAllowedOrigins } from './cors';

describe('getAllowedOrigins', () => {
  const logger = new Logger('Test');

  it('returns configured origins when provided', () => {
    const origins = getAllowedOrigins(logger, false, {
      ALLOWED_ORIGINS: 'https://example.com, https://foo.test',
    } as NodeJS.ProcessEnv);

    expect(origins).toEqual(['https://example.com', 'https://foo.test']);
  });

  it('falls back to PUBLIC_BASE_URL when ALLOWED_ORIGINS is empty', () => {
    const warnSpy = jest.spyOn(logger, 'warn');

    const origins = getAllowedOrigins(logger, false, {
      ALLOWED_ORIGINS: '',
      PUBLIC_BASE_URL: 'https://app.freetask.my',
    } as NodeJS.ProcessEnv);

    expect(origins).toEqual(['https://app.freetask.my']);
    expect(warnSpy).toHaveBeenCalled();
  });

  it('throws in production when no origins configured', () => {
    const errorSpy = jest.spyOn(logger, 'error');

    expect(() => getAllowedOrigins(logger, true, { ALLOWED_ORIGINS: '' } as NodeJS.ProcessEnv)).toThrow(
      /ALLOWED_ORIGINS and PUBLIC_BASE_URL are required in production/,
    );
    expect(errorSpy).toHaveBeenCalled();
  });
});
