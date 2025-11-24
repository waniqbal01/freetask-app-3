import { ConflictException } from '@nestjs/common';
import { JobStatus } from '@prisma/client';
import { EscrowService } from './escrow.service';

describe('EscrowService state guards', () => {
  const service = new EscrowService({} as any);

  const callPrivate = <T>(method: string, ...args: any[]) => {
    return (service as any)[method](...args) as T;
  };

  describe('ensureHoldAllowed', () => {
    const allowed = [JobStatus.PENDING, JobStatus.ACCEPTED, JobStatus.IN_PROGRESS];
    it.each(allowed)('allows hold when status is %s', (status) => {
      expect(() => callPrivate('ensureHoldAllowed', status)).not.toThrow();
    });

    it('throws for invalid states', () => {
      expect(() => callPrivate('ensureHoldAllowed', JobStatus.COMPLETED)).toThrow(
        ConflictException,
      );
    });
  });

  describe('ensureReleaseOrRefundAllowed', () => {
    it.each([JobStatus.COMPLETED, JobStatus.DISPUTED])(
      'allows release when status is %s',
      (status) => {
        expect(() => callPrivate('ensureReleaseOrRefundAllowed', status, 'release')).not.toThrow();
      },
    );

    it.each([JobStatus.CANCELLED, JobStatus.REJECTED, JobStatus.ACCEPTED])(
      'allows refund when status is %s',
      (status) => {
        expect(() => callPrivate('ensureReleaseOrRefundAllowed', status, 'refund')).not.toThrow();
      },
    );

    it('blocks release for unexpected states', () => {
      expect(() =>
        callPrivate('ensureReleaseOrRefundAllowed', JobStatus.IN_PROGRESS, 'release'),
      ).toThrow(ConflictException);
    });

    it('blocks refund for unexpected states', () => {
      expect(() => callPrivate('ensureReleaseOrRefundAllowed', JobStatus.PENDING, 'refund')).toThrow(
        ConflictException,
      );
    });
  });
});
