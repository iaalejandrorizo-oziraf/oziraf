import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdateUserStatusDto } from './update-user-status.dto';

describe('UpdateUserStatusDto', () => {
  it('accepts valid statuses', async () => {
    const dto = plainToInstance(UpdateUserStatusDto, {
      status: 'SUSPENDED',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('rejects invalid statuses', async () => {
    const dto = plainToInstance(UpdateUserStatusDto, {
      status: 'DELETED',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('status');
  });
});
