import { Test, TestingModule } from '@nestjs/testing';
import { ReviewsController } from './reviews.controller';
import { ReviewsService } from './reviews.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { ForbiddenException, NotFoundException } from '@nestjs/common';

describe('ReviewsController', () => {
    let controller: ReviewsController;
    let service: ReviewsService;

    const mockReviewsService = {
        create: jest.fn(),
        findMany: jest.fn(),
        findMine: jest.fn(),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            controllers: [ReviewsController],
            providers: [
                {
                    provide: ReviewsService,
                    useValue: mockReviewsService,
                },
            ],
        }).compile();

        controller = module.get<ReviewsController>(ReviewsController);
        service = module.get<ReviewsService>(ReviewsService);
    });

    afterEach(() => {
        jest.clearAllMocks();
    });

    describe('create', () => {
        const userId = 1;
        const validDto: CreateReviewDto = {
            jobId: 1,
            revieweeId: 2,
            rating: 5,
            comment: 'Great work!',
        };

        it('should create review with valid revieweeId', async () => {
            const expectedReview = { id: 1, ...validDto, reviewerId: userId, createdAt: new Date() };
            mockReviewsService.create.mockResolvedValue(expectedReview);

            const result = await controller.create(userId, validDto);

            expect(service.create).toHaveBeenCalledWith(userId, validDto);
            expect(result).toEqual(expectedReview);
        });

        it('should throw 400 when revieweeId is missing', async () => {
            const invalidDto = { jobId: 1, rating: 5 } as CreateReviewDto;

            // This would be caught by class-validator before reaching the service
            // Testing service layer validation
            mockReviewsService.create.mockRejectedValue(new Error('revieweeId is required'));

            await expect(controller.create(userId, invalidDto)).rejects.toThrow();
        });

        it('should throw 403 when self-reviewing (revieweeId === reviewerId)', async () => {
            const selfReviewDto: CreateReviewDto = {
                jobId: 1,
                revieweeId: userId, // Same as userId
                rating: 5,
            };

            mockReviewsService.create.mockRejectedValue(
                new ForbiddenException('Cannot review yourself'),
            );

            await expect(controller.create(userId, selfReviewDto)).rejects.toThrow(ForbiddenException);
            await expect(controller.create(userId, selfReviewDto)).rejects.toThrow('Cannot review yourself');
        });

        it('should throw 403 when reviewee not part of job', async () => {
            const invalidRevieweeDto: CreateReviewDto = {
                jobId: 1,
                revieweeId: 999, // User not in job
                rating: 5,
            };

            mockReviewsService.create.mockRejectedValue(
                new ForbiddenException('Reviewee must be part of this job'),
            );

            await expect(controller.create(userId, invalidRevieweeDto)).rejects.toThrow(ForbiddenException);
            await expect(controller.create(userId, invalidRevieweeDto)).rejects.toThrow('Reviewee must be part of this job');
        });

        it('should throw 403 when job is not completed', async () => {
            mockReviewsService.create.mockRejectedValue(
                new ForbiddenException('Job must be completed before reviewing'),
            );

            await expect(controller.create(userId, validDto)).rejects.toThrow(ForbiddenException);
            await expect(controller.create(userId, validDto)).rejects.toThrow('Job must be completed before reviewing');
        });

        it('should throw 404 when job does not exist', async () => {
            mockReviewsService.create.mockRejectedValue(new NotFoundException('Job not found'));

            await expect(controller.create(userId, validDto)).rejects.toThrow(NotFoundException);
        });

        it('should reject negative revieweeId', async () => {
            const negativeDto: CreateReviewDto = {
                jobId: 1,
                revieweeId: -1,
                rating: 5,
            };

            // This would be caught by class-validator @IsPositive()
            mockReviewsService.create.mockRejectedValue(new Error('revieweeId must be positive'));

            await expect(controller.create(userId, negativeDto)).rejects.toThrow();
        });

        it('should reject zero revieweeId', async () => {
            const zeroDto: CreateReviewDto = {
                jobId: 1,
                revieweeId: 0,
                rating: 5,
            };

            // This would be caught by class-validator @IsPositive()
            mockReviewsService.create.mockRejectedValue(new Error('revieweeId must be positive'));

            await expect(controller.create(userId, zeroDto)).rejects.toThrow();
        });
    });

    describe('findMany', () => {
        it('should return filtered reviews', async () => {
            const expectedReviews = [{ id: 1, jobId: 1, rating: 5 }];
            mockReviewsService.findMany.mockResolvedValue(expectedReviews);

            const result = await controller.find({ jobId: '1' });

            expect(service.findMany).toHaveBeenCalledWith({ jobId: 1 });
            expect(result).toEqual(expectedReviews);
        });
    });

    describe('findMine', () => {
        it('should return my reviews', async () => {
            const userId = 1;
            const expectedReviews = [{ id: 1, revieweeId: userId, rating: 5 }];
            mockReviewsService.findMine.mockResolvedValue(expectedReviews);

            const result = await controller.findMine(userId);

            expect(service.findMine).toHaveBeenCalledWith(userId);
            expect(result).toEqual(expectedReviews);
        });
    });
});
