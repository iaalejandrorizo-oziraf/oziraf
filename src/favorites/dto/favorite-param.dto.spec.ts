import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { FavoriteParamDto } from './favorite-param.dto';

describe('FavoriteParamDto', () => {
  it('accepts valid post ids', async () => {
    const dto = plainToInstance(FavoriteParamDto, {
      postId: 'post-id',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('rejects empty post ids', async () => {
    const dto = plainToInstance(FavoriteParamDto, {
      postId: '',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('postId');
  });
});
