import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { MyPostsQueryDto } from './my-posts-query.dto';

describe('MyPostsQueryDto', () => {
  it('accepts active and inactive status filters', async () => {
    const dto = plainToInstance(MyPostsQueryDto, {
      status: 'INACTIVE',
      page: '1',
      limit: '10',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.status).toBe('INACTIVE');
    expect(dto.page).toBe(1);
    expect(dto.limit).toBe(10);
  });

  it('rejects deleted status filters', async () => {
    const dto = plainToInstance(MyPostsQueryDto, {
      status: 'DELETED',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('status');
  });
});
