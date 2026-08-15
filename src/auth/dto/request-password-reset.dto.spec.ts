import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { RequestPasswordResetDto } from './request-password-reset.dto';

describe('RequestPasswordResetDto', () => {
  it('trims and accepts valid emails', async () => {
    const dto = plainToInstance(RequestPasswordResetDto, {
      email: '  user@example.com  ',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.email).toBe('user@example.com');
  });
});
