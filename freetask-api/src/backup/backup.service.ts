// Backup Service - runs daily at midnight to backup DB to Supabase Storage
import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaClient } from '@prisma/client';
import { createClient } from '@supabase/supabase-js';

@Injectable()
export class BackupService {
    private readonly logger = new Logger(BackupService.name);
    private readonly prisma = new PrismaClient();
    private readonly supabase = createClient(
        process.env.SUPABASE_URL!,
        process.env.SUPABASE_KEY!,
    );

    @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
    async handleDailyBackup() {
        this.logger.log('🔒 Starting daily database backup...');
        try {
            await this.backupDatabase();
            this.logger.log('✅ Daily backup completed successfully');
        } catch (error) {
            this.logger.error('❌ Daily backup failed:', error);
        }
    }

    async backupDatabase() {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backup: Record<string, any[]> = {};

        // Export all critical tables
        backup.users = await this.prisma.$queryRawUnsafe(`
      SELECT id, email, name, role, "avatarUrl", "isOnline", "createdAt", "updatedAt",
             state, district, "freelancerLevel"
      FROM "User"
    `);

        backup.services = await this.prisma.$queryRawUnsafe(`
      SELECT id, title, description, price, category, "freelancerId",
             "isActive", "createdAt", "updatedAt"
      FROM "Service"
    `);

        backup.jobs = await this.prisma.$queryRawUnsafe(`
      SELECT id, title, description, status, amount, "serviceId",
             "clientId", "freelancerId", "createdAt", "updatedAt",
             "conversationId", "submitUrl", "revisionNote", "disputeReason"
      FROM "Job"
    `);

        backup.escrows = await this.prisma.$queryRawUnsafe(`
      SELECT id, "jobId", status, amount, "createdAt", "updatedAt"
      FROM "Escrow"
    `);

        backup.reviews = await this.prisma.$queryRawUnsafe(`
      SELECT id, "jobId", "reviewerId", "revieweeId", rating, comment, "createdAt"
      FROM "Review"
    `);

        backup.conversations = await this.prisma.$queryRawUnsafe(`
      SELECT id, "jobId", "createdAt", "updatedAt"
      FROM "Conversation"
    `);

        backup.chatMessages = await this.prisma.$queryRawUnsafe(`
      SELECT id, "jobId", "senderId", content, type, "attachmentUrl",
             "replyToId", "createdAt", "deliveredAt", "readAt"
      FROM "ChatMessage"
      ORDER BY "createdAt" DESC
      LIMIT 10000
    `);

        backup.bankDetails = await this.prisma.$queryRawUnsafe(`
      SELECT id, "userId", "bankName", "accountNumber", "accountName",
             "isVerified", "createdAt"
      FROM "BankDetail"
    `);

        // Convert BigInt to string for JSON serialization
        const jsonStr = JSON.stringify(backup, (_, v) =>
            typeof v === 'bigint' ? v.toString() : v,
        );

        const filename = `backups/freetask-db-${timestamp}.json`;
        const { error } = await this.supabase.storage
            .from('uploads')
            .upload(filename, Buffer.from(jsonStr), {
                contentType: 'application/json',
                upsert: false,
            });

        if (error) throw error;

        this.logger.log(`💾 Backup saved to Supabase Storage: ${filename}`);
        this.logger.log(
            `📊 Backed up: ${(backup.users as any[]).length} users, ${(backup.jobs as any[]).length} jobs`,
        );

        return filename;
    }
}
