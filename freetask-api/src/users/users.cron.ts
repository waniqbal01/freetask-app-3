import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { FreelancerLevel, User } from '@prisma/client';

@Injectable()
export class UsersCron {
    private readonly logger = new Logger(UsersCron.name);

    constructor(private readonly prisma: PrismaService) { }

    @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
    async evaluateFreelancerLevels() {
        this.logger.log('Starting daily evaluation of freelancer levels...');

        const freelancers = await this.prisma.user.findMany({
            where: { role: 'FREELANCER', isActive: true },
        });

        for (const user of freelancers) {
            try {
                await this.evaluateUserLevel(user);
            } catch (error) {
                this.logger.error(`Failed to evaluate level for user ${user.id}`, error);
            }
        }

        this.logger.log('Completed daily evaluation of freelancer levels.');
    }

    public async evaluateUserLevel(user: User) {
        const targetLevel = this.calculateTargetLevel(user);

        let newLevel = user.level;
        let strikes = user.levelDowngradeStrikes;

        const levelRank = {
            [FreelancerLevel.NEWBIE]: 1,
            [FreelancerLevel.STANDARD]: 2,
            [FreelancerLevel.PRO]: 3,
        };

        if (targetLevel !== user.level) {
            // If target level is lower than current -> potential downgrade
            if (levelRank[targetLevel] < levelRank[user.level]) {
                strikes += 1;
                if (strikes >= 3) {
                    // 3 days grace period exceeded, downgrade
                    newLevel = targetLevel;
                    strikes = 0;
                    this.logger.log(
                        `User ${user.id} downgraded to ${newLevel} after 3 days grace period.`,
                    );
                } else {
                    this.logger.log(
                        `User ${user.id} missed criteria for ${user.level}. Strike ${strikes}/3.`,
                    );
                }
            } else {
                // Upgrade immediately
                newLevel = targetLevel;
                strikes = 0;
                this.logger.log(`User ${user.id} upgraded to ${newLevel}!`);
            }
        } else {
            // User meets current level criteria, reset strikes if any
            if (strikes > 0) {
                strikes = 0;
                this.logger.log(`User ${user.id} recovered. Strikes reset to 0.`);
            }
        }

        // Also compute actual replyRate for DB caching
        const incoming = user.totalIncomingRequests;
        const replied = user.totalRepliedRequests;
        const replyRate = incoming > 0 ? (replied / incoming) * 100 : null;

        await this.prisma.user.update({
            where: { id: user.id },
            data: {
                level: newLevel,
                levelDowngradeStrikes: strikes,
                replyRate: replyRate,
            },
        });
    }

    private calculateTargetLevel(user: User): FreelancerLevel {
        const jobs = user.totalCompletedJobs;
        const reviews = user.totalReviews;
        const ratingScore = Number(user.totalRatingScore);
        const incoming = user.totalIncomingRequests;
        const replied = user.totalRepliedRequests;

        const rating = reviews > 0 ? ratingScore / reviews : 0;

        let replyRate = 0;
        if (incoming > 0) {
            replyRate = (replied / incoming) * 100;
        }

        // Pro Requirements
        const isPro =
            jobs >= 30 &&
            reviews >= 5 &&
            rating >= 4.7 &&
            incoming >= 5 &&
            replyRate >= 95;

        if (isPro) return FreelancerLevel.PRO;

        // Standard Requirements
        // "rating >= 4.3 (min 5 reviews, or NA - meaning if reviews < 5, treated as passing for Standard)"
        const standardRatingPassed = reviews < 5 || rating >= 4.3;

        // "reply rate >= 85% (if >= 5 reqs). If < 5, treated as passing for Standard"
        const standardReplyRatePassed = incoming < 5 || replyRate >= 85;

        const isStandard =
            jobs >= 10 && standardRatingPassed && standardReplyRatePassed;

        if (isStandard) return FreelancerLevel.STANDARD;

        // Default
        return FreelancerLevel.NEWBIE;
    }
}
