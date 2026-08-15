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
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.q).toBe('arquitectura');
    expect(dto.city).toBe('Guadalajara');
    expect(dto.page).toBe(2);
    expect(dto.limit).toBe(10);
  });
});
