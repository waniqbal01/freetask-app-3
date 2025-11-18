import { INestApplication, Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    try {
      await this.$connect();
    } catch (error) {
      const hasDatabaseUrl = Boolean(process.env.DATABASE_URL);
      console.error(
        hasDatabaseUrl
          ? 'DATABASE_URL is set but the database is not reachable. Ensure Postgres is running and migrations have been executed.'
          : 'DATABASE_URL is missing or invalid. Please set a valid DATABASE_URL before starting the server.',
        error,
      );
      // TODO: Ensure the database service is up and migrations are applied before booting the API.
      throw error;
    }
  }

  async enableShutdownHooks(app: INestApplication) {
    this.$on('beforeExit' as never, async () => {
      await app.close();
    });
  }
}
