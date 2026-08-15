import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdateProfileDto } from './update-profile.dto';

describe('UpdateProfileDto', () => {
  it('trims optional profile fields', async () => {
    const dto = plainToInstance(UpdateProfileDto, {
      firstName: '  Alejandro  ',
      profession: '  Arquitecto  ',
      profilePhoto: '  https://example.com/profile.jpg  ',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.firstName).toBe('Alejandro');
    expect(dto.profession).toBe('Arquitecto');
    expect(dto.profilePhoto).toBe('https://example.com/profile.jpg');
  });

  it('rejects invalid profile photo url', async () => {
    const dto = plainToInstance(UpdateProfileDto, {
      profilePhoto: 'example.com/profile.jpg',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('profilePhoto');
  });
});
