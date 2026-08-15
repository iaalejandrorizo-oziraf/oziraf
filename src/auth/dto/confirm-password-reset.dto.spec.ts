import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ConfirmPasswordResetDto } from './confirm-password-reset.dto';

describe('ConfirmPasswordResetDto', () => {
  it('accepts valid reset data', async () => {
    const dto = plainToInstance(ConfirmPasswordResetDto, {
      token: 'reset-token',
      newPassword: 'NewPassword123',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('rejects short new passwords', async () => {
    const dto = plainToInstance(ConfirmPasswordResetDto, {
      token: 'reset-token',
      newPassword: 'short',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('newPassword');
  });
});
