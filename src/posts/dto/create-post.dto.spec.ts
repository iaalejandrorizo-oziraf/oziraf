import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CreatePostDto } from './create-post.dto';

describe('CreatePostDto', () => {
  it('trims post fields and accepts valid data', async () => {
    const dto = plainToInstance(CreatePostDto, {
      title: '  Servicio de arquitectura  ',
      description: '  Diseno y remodelacion residencial.  ',
      category: '  Arquitectura  ',
      country: '  Mexico  ',
      city: '  Guadalajara  ',
      state: '  Jalisco  ',
      neighborhood: '  Americana  ',
      price: 2500,
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.title).toBe('Servicio de arquitectura');
    expect(dto.category).toBe('Arquitectura');
    expect(dto.neighborhood).toBe('Americana');
  });

  it('rejects empty required fields and non-positive prices', async () => {
    const dto = plainToInstance(CreatePostDto, {
      title: '   ',
      description: '   ',
      category: 'Arquitectura',
      country: 'Mexico',
      city: 'Guadalajara',
      state: 'Jalisco',
      price: 0,
    });

    const errors = await validate(dto);
    const properties = errors.map((error) => error.property);

    expect(properties).toEqual(expect.arrayContaining(['title']));
    expect(properties).toEqual(expect.arrayContaining(['description']));
    expect(properties).toEqual(expect.arrayContaining(['price']));
  });
});
