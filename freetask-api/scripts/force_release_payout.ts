import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { AdminService } from '../src/admin/admin.service';
import { Logger } from '@nestjs/common';

async function bootstrap() {
    const logger = new Logger('ManualPayoutRelease');
    const app = await NestFactory.createApplicationContext(AppModule);
    const adminService = app.get(AdminService);

    // Job ID from User Screenshot
    const JOB_ID = 9;
    // System Admin ID (Using 1 as default)
    const ADMIN_ID = 1;

    logger.log(`Releasing Payout for Job #${JOB_ID}...`);

    try {
        const result = await adminService.releasePayoutHold(JOB_ID, ADMIN_ID);
        logger.log('Payout Release Result:');
        console.log(JSON.stringify(result, null, 2));
    } catch (error: any) {
        logger.error('Failed to release payout:', error.message);
        console.error(error);
    }

    await app.close();
}

bootstrap();
