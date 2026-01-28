
import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module'; // Correct relative path
import { AdminService } from '../src/admin/admin.service'; // Correct relative path
import { Logger } from '@nestjs/common';

async function bootstrap() {
    const logger = new Logger('ManualMarkPaid');
    const app = await NestFactory.createApplicationContext(AppModule);
    const adminService = app.get(AdminService);

    // Job ID from User Request
    const JOB_ID = 9;
    const ADMIN_ID = 1;

    logger.log(`Marking Job #${JOB_ID} as PAID_OUT (Manual Override)...`);

    try {
        // Updated to use the new method
        const result = await adminService.markJobPaidManually(JOB_ID, ADMIN_ID, 'Force resolve via script');
        logger.log('Update Result:');
        console.log(JSON.stringify(result, null, 2));
    } catch (error: any) {
        logger.error('Failed to mark paid:', error.message);
        console.error(error);
    }

    await app.close();
}

bootstrap();
