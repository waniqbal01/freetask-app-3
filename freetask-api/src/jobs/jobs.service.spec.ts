import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { JobStatus, UserRole } from '@prisma/client';
import { JobsService } from './jobs.service';
import { PrismaService } from '../prisma/prisma.service';

describe('JobsService', () => {
  let service: JobsService;
  let prisma: {
    service: {
      findUnique: jest.Mock;
    };
    job: {
      create: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
      findFirst: jest.Mock;
      findMany: jest.Mock;
    };
  };

  const mockService = {
    id: 10,
    title: 'UX Review',
    description: 'Review app',
    price: 500,
    freelancerId: 77,
  };

  const baseJob = {
    id: 33,
    status: JobStatus.PENDING,
    clientId: 11,
    freelancerId: 77,
  };

  beforeEach(() => {
    prisma = {
      service: {
        findUnique: jest.fn(),
      },
      job: {
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
      },
    };

    service = new JobsService(prisma as unknown as PrismaService);
  });

  it('allows client to create job for a service', async () => {
    prisma.service.findUnique.mockResolvedValue(mockService);
    prisma.job.create.mockResolvedValue({ ...baseJob });

    const dto = {
      serviceId: mockService.id,
      description: 'Need quick help',
      amount: 650,
    } as any;

    const job = await service.create(11, UserRole.CLIENT, dto);

    expect(job.id).toBe(baseJob.id);
    expect(prisma.job.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ freelancerId: mockService.freelancerId }),
      }),
    );
  });

  it('blocks non-clients from creating jobs', async () => {
    await expect(
      service.create(11, UserRole.FREELANCER, { serviceId: 1, description: 'x' } as any),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('lets freelancer move job through lifecycle', async () => {
    prisma.job.findUnique
      .mockResolvedValueOnce({ ...baseJob })
      .mockResolvedValueOnce({ ...baseJob, status: JobStatus.ACCEPTED })
      .mockResolvedValueOnce({ ...baseJob, status: JobStatus.IN_PROGRESS })
      .mockResolvedValue({ ...baseJob, status: JobStatus.IN_PROGRESS });

    prisma.job.update.mockImplementation(({ data }) => ({ ...baseJob, status: data.status }));

    const accepted = await service.acceptJob(baseJob.id, baseJob.freelancerId);
    expect(accepted.status).toBe(JobStatus.ACCEPTED);

    const started = await service.startJob(baseJob.id, baseJob.freelancerId);
    expect(started.status).toBe(JobStatus.IN_PROGRESS);

    const completed = await service.completeJob(baseJob.id, baseJob.clientId);
    expect(completed.status).toBe(JobStatus.COMPLETED);
  });

  it('prevents other freelancers from updating jobs they do not own', async () => {
    prisma.job.findUnique.mockResolvedValue(baseJob);

    await expect(service.acceptJob(baseJob.id, 1000)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('throws when job not found on status updates', async () => {
    prisma.job.findUnique.mockResolvedValue(null);
    await expect(service.acceptJob(baseJob.id, baseJob.freelancerId)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
