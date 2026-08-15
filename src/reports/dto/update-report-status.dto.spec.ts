import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdateReportStatusDto } from './update-report-status.dto';

describe('UpdateReportStatusDto', () => {
  it('accepts valid report statuses', async () => {
    const dto = plainToInstance(UpdateReportStatusDto, {
      status: 'RESOLVED',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('rejects invalid report statuses', async () => {
    const dto = plainToInstance(UpdateReportStatusDto, {
      status: 'BAD',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('status');
  });
});
