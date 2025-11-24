import { ConflictException, ForbiddenException } from '@nestjs/common';
import { JobStatus, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { JobsService } from './jobs.service';

const baseJob = {
  id: 1,
  clientId: 10,
  freelancerId: 20,
  status: JobStatus.PENDING,
};

const jobIncludeResult = {
  ...baseJob,
  title: 'Test Job',
  description: 'desc',
  amount: 100,
  service: { id: 1, title: 'Service' },
  client: { id: baseJob.clientId, name: 'Client' },
  freelancer: { id: baseJob.freelancerId, name: 'Freelancer' },
};

describe('JobsService', () => {
  let prisma: jest.Mocked<Pick<PrismaService, 'job'>>;
  let service: JobsService;

  beforeEach(() => {
    prisma = {
      job: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
    } as unknown as jest.Mocked<Pick<PrismaService, 'job'>>;

    service = new JobsService(prisma as unknown as PrismaService);
  });

  it('prevents freelancers from cancelling jobs through updateStatus', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);

    await expect(
      service.updateStatus(baseJob.id, baseJob.freelancerId, UserRole.FREELANCER, {
        status: JobStatus.CANCELLED,
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.job.update).not.toHaveBeenCalled();
  });

  it('allows freelancers to move through valid transitions', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);
    (prisma.job.update as jest.Mock).mockResolvedValue({
      ...jobIncludeResult,
      status: JobStatus.ACCEPTED,
    });

    const result = await service.updateStatus(
      baseJob.id,
      baseJob.freelancerId,
      UserRole.FREELANCER,
      { status: JobStatus.ACCEPTED },
    );

    expect(prisma.job.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: baseJob.id },
        data: { status: JobStatus.ACCEPTED, disputeReason: null },
      }),
    );
    expect(result.status).toBe(JobStatus.ACCEPTED);
  });

  it('keeps client cancellation flow intact', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);
    (prisma.job.update as jest.Mock).mockResolvedValue({
      ...jobIncludeResult,
      status: JobStatus.CANCELLED,
    });

    const result = await service.cancelJob(baseJob.id, baseJob.clientId, UserRole.CLIENT);

    expect(prisma.job.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: baseJob.id },
        data: { status: JobStatus.CANCELLED, disputeReason: null },
      }),
    );
    expect(result.status).toBe(JobStatus.CANCELLED);
  });

  it('rejects invalid transitions regardless of role', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue({ ...baseJob, status: JobStatus.COMPLETED });

    await expect(
      service.updateStatus(baseJob.id, baseJob.freelancerId, UserRole.FREELANCER, {
        status: JobStatus.ACCEPTED,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('blocks clients from freelancer-only actions', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);

    await expect(service.acceptJob(baseJob.id, baseJob.clientId, UserRole.CLIENT)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    await expect(service.startJob(baseJob.id, baseJob.clientId, UserRole.CLIENT)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    await expect(service.rejectJob(baseJob.id, baseJob.clientId, UserRole.CLIENT)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('prevents freelancers from cancelling or disputing as clients', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);

    await expect(service.cancelJob(baseJob.id, baseJob.freelancerId, UserRole.FREELANCER)).rejects.toBeInstanceOf(
      ForbiddenException,
    );

    await expect(
      service.disputeJob(baseJob.id, baseJob.clientId, UserRole.CLIENT, {
        reason: 'Not satisfied',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
