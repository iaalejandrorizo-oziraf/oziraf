import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CreateContactLeadDto } from './create-contact-lead.dto';

describe('CreateContactLeadDto', () => {
  it('trims and accepts valid messages', async () => {
    const dto = plainToInstance(CreateContactLeadDto, {
      message: '  Me interesa tu servicio de arquitectura.  ',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect(dto.message).toBe('Me interesa tu servicio de arquitectura.');
  });

  it('rejects short messages', async () => {
    const dto = plainToInstance(CreateContactLeadDto, {
      message: 'Hola',
    });

    const errors = await validate(dto);

    expect(errors.map((error) => error.property)).toContain('message');
  });
});
