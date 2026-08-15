import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdatePostStatusDto } from './update-post-status.dto';

describe('UpdatePostStatusDto', () => {
  it('accepts active and inactive statuses', async () => {
    const activeDto = plainToInstance(UpdatePostStatusDto, {
      status: 'ACTIVE',
    });
    const inactiveDto = plainToInstance(UpdatePostStatusDto, {
      status: 'INACTIVE',
    });

    await expect(validate(activeDto)).resolves.toHaveLength(0);
    await expect(validate(inactiveDto)).resolves.toHaveLength(0);
  });

  it('rejects deleted status updates', async () => {
    const dto = plainToInstance(UpdatePostStatusDto, {
      status: 'DELETED',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('status');
  });
});
