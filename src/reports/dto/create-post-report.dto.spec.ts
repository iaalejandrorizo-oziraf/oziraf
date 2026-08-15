import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CreatePostReportDto } from './create-post-report.dto';

describe('CreatePostReportDto', () => {
  it('accepts valid report data', async () => {
    const dto = plainToInstance(CreatePostReportDto, {
      reason: 'FRAUD',
      details: '  Parece una publicación falsa.  ',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.details).toBe('Parece una publicación falsa.');
  });

  it('rejects invalid report reasons', async () => {
    const dto = plainToInstance(CreatePostReportDto, {
      reason: 'BAD',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('reason');
  });
});
