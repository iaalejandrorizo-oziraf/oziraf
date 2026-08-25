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

  it('accepts social links and allows clearing them', async () => {
    const dto = plainToInstance(UpdateProfileDto, {
      whatsapp: '  +52 228 123 4567  ',
      instagramUrl: '  https://instagram.com/oziraf  ',
      facebookUrl: '',
      tiktokUrl: '  https://tiktok.com/@oziraf  ',
      xUrl: '  https://x.com/oziraf  ',
      websiteUrl: '',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.whatsapp).toBe('+52 228 123 4567');
    expect(dto.instagramUrl).toBe('https://instagram.com/oziraf');
    expect(dto.tiktokUrl).toBe('https://tiktok.com/@oziraf');
    expect(dto.xUrl).toBe('https://x.com/oziraf');
  });
});
