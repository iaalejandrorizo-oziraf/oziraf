import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ChangePasswordDto } from './change-password.dto';

describe('ChangePasswordDto', () => {
  it('accepts valid passwords', async () => {
    const dto = plainToInstance(ChangePasswordDto, {
      currentPassword: 'Password123',
      newPassword: 'NewPassword123',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('rejects short passwords', async () => {
    const dto = plainToInstance(ChangePasswordDto, {
      currentPassword: 'short',
      newPassword: 'short',
    });

    const errors = await validate(dto);
    const properties = errors.map((error) => error.property);

    expect(properties).toEqual(
      expect.arrayContaining(['currentPassword', 'newPassword']),
    );
  });
});
