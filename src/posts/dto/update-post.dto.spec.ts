import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdatePostDto } from './update-post.dto';

describe('UpdatePostDto', () => {
  it('accepts partial post updates and trims text fields', async () => {
    const dto = plainToInstance(UpdatePostDto, {
      title: '  Servicio actualizado  ',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.title).toBe('Servicio actualizado');
  });

  it('rejects empty text fields and non-positive prices when provided', async () => {
    const dto = plainToInstance(UpdatePostDto, {
      title: '   ',
      price: 0,
    });

    const errors = await validate(dto);
    const properties = errors.map((error) => error.property);

    expect(properties).toEqual(expect.arrayContaining(['title', 'price']));
  });
});
