import { JobStatus } from '@prisma/client';

// Canonical job status values shared with Flutter + Swagger. Update this file
// if Prisma enum changes to keep contract in one place for testers.
export const JOB_STATUS_FLOW: Record<JobStatus, JobStatus[]> = {
  [JobStatus.PENDING]: [JobStatus.ACCEPTED, JobStatus.REJECTED],
  [JobStatus.ACCEPTED]: [
    JobStatus.IN_PROGRESS,
    JobStatus.CANCELLED,
    JobStatus.DISPUTED,
  ],
  [JobStatus.IN_PROGRESS]: [
    JobStatus.COMPLETED,
    JobStatus.CANCELLED,
    JobStatus.DISPUTED,
  ],
  [JobStatus.COMPLETED]: [JobStatus.DISPUTED],
  [JobStatus.CANCELLED]: [],
  [JobStatus.REJECTED]: [],
  [JobStatus.DISPUTED]: [],
};

export const JOB_STATUS_DESCRIPTIONS: Record<JobStatus, string> = {
  [JobStatus.PENDING]: 'Menunggu tindakan client/freelancer',
  [JobStatus.ACCEPTED]: 'Telah diterima client',
  [JobStatus.IN_PROGRESS]: 'Kerja sedang dijalankan',
  [JobStatus.COMPLETED]: 'Kerja selesai',
  [JobStatus.CANCELLED]: 'Dibatalkan',
  [JobStatus.REJECTED]: 'Ditolak freelancer',
  [JobStatus.DISPUTED]: 'Dalam pertikaian',
};
