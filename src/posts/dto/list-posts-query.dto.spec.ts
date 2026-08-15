import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ListPostsQueryDto } from './list-posts-query.dto';

describe('ListPostsQueryDto', () => {
  it('transforms valid pagination query values to numbers', async () => {
    const dto = plainToInstance(ListPostsQueryDto, {
      page: '2',
      limit: '10',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.page).toBe(2);
    expect(dto.limit).toBe(10);
  });

  it('rejects invalid pagination values', async () => {
    const dto = plainToInstance(ListPostsQueryDto, {
      page: '0',
      limit: '100',
    });

    const errors = await validate(dto);
    const properties = errors.map((error) => error.property);

    expect(properties).toEqual(expect.arrayContaining(['page', 'limit']));
  });
});
