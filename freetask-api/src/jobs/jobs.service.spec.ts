import { ConflictException, ForbiddenException } from '@nestjs/common';
import { JobStatus, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { JobsService } from './jobs.service';
import { EscrowService } from '../escrow/escrow.service';

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
  let prisma: jest.Mocked<Pick<PrismaService, 'job' | '$transaction'>> & {
    escrow: { findUnique: jest.Mock };
  };
  let escrowService: jest.Mocked<Pick<EscrowService, 'syncOnJobStatus'>>;
  let service: JobsService;
  let txJobUpdate: jest.Mock;
  let txEscrowUpdate: jest.Mock;

  beforeEach(() => {
    txJobUpdate = jest.fn();
    txEscrowUpdate = jest.fn();
    prisma = {
      job: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      escrow: { findUnique: jest.fn() },
      $transaction: jest.fn(async (cb: any) =>
        cb({
          job: { update: txJobUpdate },
          escrow: {
            findUnique: prisma.escrow.findUnique,
            update: txEscrowUpdate,
          },
        } as any),
      ),
    } as unknown as jest.Mocked<Pick<PrismaService, 'job' | '$transaction'>> & {
      escrow: { findUnique: jest.Mock };
    };

    escrowService = {
      syncOnJobStatus: jest.fn(),
    } as unknown as jest.Mocked<Pick<EscrowService, 'syncOnJobStatus'>>;

    service = new JobsService(
      prisma as unknown as PrismaService,
      escrowService,
    );
  });

  it('prevents freelancers from cancelling jobs through updateStatus', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);

    await expect(
      service.updateStatus(
        baseJob.id,
        baseJob.freelancerId,
        UserRole.FREELANCER,
        {
          status: JobStatus.CANCELED,
        },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(txJobUpdate).not.toHaveBeenCalled();
  });

  it('allows freelancers to move through valid transitions', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);
    txJobUpdate.mockResolvedValue({
      ...jobIncludeResult,
      status: JobStatus.ACCEPTED,
    });

    const result = await service.updateStatus(
      baseJob.id,
      baseJob.freelancerId,
      UserRole.FREELANCER,
      { status: JobStatus.ACCEPTED },
    );

    expect(txJobUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: baseJob.id },
        data: { status: JobStatus.ACCEPTED, disputeReason: null },
      }),
    );
    expect(result.status).toBe(JobStatus.ACCEPTED);
  });

  it('keeps client cancellation flow intact', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);
    txJobUpdate.mockResolvedValue({
      ...jobIncludeResult,
      status: JobStatus.CANCELED,
    });

    const result = await service.cancelJob(
      baseJob.id,
      baseJob.clientId,
      UserRole.CLIENT,
    );

    expect(txJobUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: baseJob.id },
        data: { status: JobStatus.CANCELED, disputeReason: null },
      }),
    );
    expect(result.status).toBe(JobStatus.CANCELED);
  });

  it('rejects invalid transitions regardless of role', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue({
      ...baseJob,
      status: JobStatus.COMPLETED,
    });

    await expect(
      service.updateStatus(
        baseJob.id,
        baseJob.freelancerId,
        UserRole.FREELANCER,
        {
          status: JobStatus.ACCEPTED,
        },
      ),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('blocks clients from freelancer-only actions', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);

    await expect(
      service.acceptJob(baseJob.id, baseJob.clientId, UserRole.CLIENT),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      service.startJob(baseJob.id, baseJob.clientId, UserRole.CLIENT),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      service.rejectJob(baseJob.id, baseJob.clientId, UserRole.CLIENT),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('prevents freelancers from cancelling or disputing as clients', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);

    await expect(
      service.cancelJob(baseJob.id, baseJob.freelancerId, UserRole.FREELANCER),
    ).rejects.toBeInstanceOf(ForbiddenException);

    await expect(
      service.disputeJob(baseJob.id, baseJob.clientId, UserRole.CLIENT, {
        reason: 'Not satisfied',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('syncs escrow when completing a job', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue({
      ...baseJob,
      status: JobStatus.IN_PROGRESS,
    });
    txJobUpdate.mockResolvedValue({
      ...jobIncludeResult,
      status: JobStatus.COMPLETED,
    });
    prisma.escrow.findUnique.mockResolvedValue({
      id: 2,
      jobId: baseJob.id,
      status: 'HELD',
    });

    await service.completeJob(
      baseJob.id,
      baseJob.freelancerId,
      UserRole.FREELANCER,
    );

    expect(escrowService.syncOnJobStatus).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ id: baseJob.id, status: JobStatus.COMPLETED }),
      expect.objectContaining({ id: 2, status: 'HELD' }),
    );
  });

  it('syncs escrow when cancelling a job', async () => {
    (prisma.job.findUnique as jest.Mock).mockResolvedValue(baseJob);
    txJobUpdate.mockResolvedValue({
      ...jobIncludeResult,
      status: JobStatus.CANCELED,
    });
    prisma.escrow.findUnique.mockResolvedValue({
      id: 3,
      jobId: baseJob.id,
      status: 'PENDING',
    });

    await service.cancelJob(baseJob.id, baseJob.clientId, UserRole.CLIENT);

    expect(escrowService.syncOnJobStatus).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ id: baseJob.id, status: JobStatus.CANCELED }),
      expect.objectContaining({ id: 3, status: 'PENDING' }),
    );
  });
});
