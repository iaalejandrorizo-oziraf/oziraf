import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { SearchPostsQueryDto } from './search-posts-query.dto';

describe('SearchPostsQueryDto', () => {
  it('trims filters and transforms pagination values', async () => {
    const dto = plainToInstance(SearchPostsQueryDto, {
      q: '  arquitectura  ',
      city: '  Guadalajara  ',
      page: '2',
      limit: '10',
      minPrice: '1000',
      maxPrice: '3000',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.q).toBe('arquitectura');
    expect(dto.city).toBe('Guadalajara');
    expect(dto.page).toBe(2);
    expect(dto.limit).toBe(10);
    expect(dto.minPrice).toBe(1000);
    expect(dto.maxPrice).toBe(3000);
  });

  it('rejects non-positive price filters', async () => {
    const dto = plainToInstance(SearchPostsQueryDto, {
      minPrice: '0',
      maxPrice: '-1',
    });

    const errors = await validate(dto);
    const properties = errors.map((error) => error.property);

    expect(properties).toEqual(expect.arrayContaining(['minPrice', 'maxPrice']));
  });
});
