import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ConfirmEmailVerificationDto } from './confirm-email-verification.dto';

describe('ConfirmEmailVerificationDto', () => {
  it('accepts valid tokens', async () => {
    const dto = plainToInstance(ConfirmEmailVerificationDto, {
      token: 'verification-token',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });
});
