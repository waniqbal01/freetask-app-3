import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { JOB_MIN_AMOUNT, JOB_MIN_DESC_LEN } from '../constants';
import { CreateJobDto } from './create-job.dto';

describe('CreateJobDto validation', () => {
  it('accepts payload at minimum thresholds', async () => {
    const dto = plainToInstance(CreateJobDto, {
      serviceId: 1,
      title: 'Test',
      description: 'x'.repeat(JOB_MIN_DESC_LEN),
      amount: JOB_MIN_AMOUNT,
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('rejects description or amount below minimum', async () => {
    const dto = plainToInstance(CreateJobDto, {
      serviceId: 1,
      description: 'x'.repeat(JOB_MIN_DESC_LEN - 1),
      amount: JOB_MIN_AMOUNT - 0.5,
    });

    const errors = await validate(dto);
    const properties = errors.map((error) => error.property);

    expect(properties).toContain('description');
    expect(properties).toContain('amount');
  });
});
