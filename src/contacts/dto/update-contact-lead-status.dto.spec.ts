import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdateContactLeadStatusDto } from './update-contact-lead-status.dto';

describe('UpdateContactLeadStatusDto', () => {
  it('accepts valid lead statuses', async () => {
    const dto = plainToInstance(UpdateContactLeadStatusDto, {
      status: 'READ',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('rejects invalid lead statuses', async () => {
    const dto = plainToInstance(UpdateContactLeadStatusDto, {
      status: 'DELETED',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('status');
  });
});
