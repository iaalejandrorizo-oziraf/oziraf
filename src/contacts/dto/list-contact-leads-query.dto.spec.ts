import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ListContactLeadsQueryDto } from './list-contact-leads-query.dto';

describe('ListContactLeadsQueryDto', () => {
  it('accepts pagination and status filters', async () => {
    const dto = plainToInstance(ListContactLeadsQueryDto, {
      page: '2',
      limit: '10',
      status: 'NEW',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.page).toBe(2);
    expect(dto.limit).toBe(10);
    expect(dto.status).toBe('NEW');
  });

  it('rejects invalid status filters', async () => {
    const dto = plainToInstance(ListContactLeadsQueryDto, {
      status: 'DELETED',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('status');
  });
});
