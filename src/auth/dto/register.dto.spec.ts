import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { RegisterDto } from './register.dto';

describe('RegisterDto', () => {
  it('trims text fields and accepts valid data', async () => {
    const dto = plainToInstance(RegisterDto, {
      email: '  user@example.com  ',
      password: 'Password123',
      firstName: '  Alejandro  ',
      city: '  Guadalajara  ',
      profilePhoto: '  https://example.com/profile.jpg  ',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.email).toBe('user@example.com');
    expect(dto.firstName).toBe('Alejandro');
    expect(dto.city).toBe('Guadalajara');
    expect(dto.profilePhoto).toBe('https://example.com/profile.jpg');
  });

  it('rejects empty first name and invalid profile photo url', async () => {
    const dto = plainToInstance(RegisterDto, {
      email: 'user@example.com',
      password: 'Password123',
      firstName: '   ',
      profilePhoto: 'example.com/profile.jpg',
    });

    const errors = await validate(dto);
    const properties = errors.map((error) => error.property);

    expect(properties).toEqual(expect.arrayContaining(['firstName']));
    expect(properties).toEqual(expect.arrayContaining(['profilePhoto']));
  });
});
