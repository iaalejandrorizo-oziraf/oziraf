import { BadRequestException } from '@nestjs/common';
import { assertPostContentAllowed } from './post-content-policy';

describe('assertPostContentAllowed', () => {
  it('allows normal service ads', () => {
    expect(() =>
      assertPostContentAllowed({
        title: 'Plomeria residencial',
        description: 'Reparacion de fugas e instalacion de llaves.',
        category: 'Mantenimiento',
      }),
    ).not.toThrow();
  });

  it('rejects offensive language', () => {
    expect(() =>
      assertPostContentAllowed({
        title: 'Servicio tecnico',
        description: 'Atencion para pendejo',
        category: 'Reparaciones',
      }),
    ).toThrow(BadRequestException);
  });

  it('rejects illegal products or services', () => {
    expect(() =>
      assertPostContentAllowed({
        title: 'Documentos falsos',
        description: 'Entrega rapida',
        category: 'Gestoria',
      }),
    ).toThrow(BadRequestException);

    expect(() =>
      assertPostContentAllowed({
        title: 'Venta de armas',
        description: 'Producto disponible',
        category: 'Seguridad',
      }),
    ).toThrow(BadRequestException);
  });
});
