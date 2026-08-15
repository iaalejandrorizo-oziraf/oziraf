import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ListReportsQueryDto } from './list-reports-query.dto';

describe('ListReportsQueryDto', () => {
  it('accepts pagination and status filters', async () => {
    const dto = plainToInstance(ListReportsQueryDto, {
      page: '2',
      limit: '10',
      status: 'OPEN',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.page).toBe(2);
    expect(dto.limit).toBe(10);
    expect(dto.status).toBe('OPEN');
  });

  it('rejects invalid report status filters', async () => {
    const dto = plainToInstance(ListReportsQueryDto, {
      status: 'BAD',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('status');
  });
});
