import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ListUsersQueryDto } from './list-users-query.dto';

describe('ListUsersQueryDto', () => {
  it('accepts pagination, status and role filters', async () => {
    const dto = plainToInstance(ListUsersQueryDto, {
      page: '2',
      limit: '10',
      status: 'ACTIVE',
      role: 'USER',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.page).toBe(2);
    expect(dto.limit).toBe(10);
    expect(dto.status).toBe('ACTIVE');
    expect(dto.role).toBe('USER');
  });

  it('rejects invalid filters', async () => {
    const dto = plainToInstance(ListUsersQueryDto, {
      status: 'BAD',
      role: 'OWNER',
    });

    const errors = await validate(dto);
    const properties = errors.map((error) => error.property);

    expect(properties).toEqual(expect.arrayContaining(['status', 'role']));
  });
});
