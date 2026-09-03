import { BadRequestException } from '@nestjs/common';

type PostContentInput = {
  title?: string;
  description?: string;
  category?: string;
};

const offensiveTerms = [
  'cabron',
  'cabrón',
  'chingada',
  'chingado',
  'chingar',
  'culero',
  'estupido',
  'estúpido',
  'idiota',
  'imbecil',
  'imbécil',
  'mierda',
  'pendejo',
  'puta',
  'puto',
];

const illegalOfferPatterns = [
  /\b(?:arma|armas|pistola|pistolas|rifle|rifles|municion|munición)\b/i,
  /\b(?:droga|drogas|cocaina|cocaína|marihuana|fentanilo|cristal|metanfetamina)\b/i,
  /\b(?:pasaporte|ine|identificacion|identificación|licencia)\s+(?:falso|falsa|falsos|falsas)\b/i,
  /\b(?:documentos?|certificados?|facturas?)\s+(?:falsos?|apocrifos?|apócrifos?)\b/i,
  /\b(?:hackeo|hackear|robo\s+de\s+cuentas|cuentas\s+robadas|clonacion|clonación)\b/i,
  /\b(?:tarjetas?\s+clonadas?|skimmer|carding|cvv)\b/i,
  /\b(?:servicio\s+sexual|escort|prostitucion|prostitución)\b/i,
  /\b(?:organos|órganos)\b/i,
  /\b(?:fauna\s+silvestre|animales?\s+exoticos?|animales?\s+exóticos?)\b/i,
];

const offensiveRegexes = offensiveTerms.map(
  (term) => new RegExp(`(^|[^\\p{L}\\p{N}])${escapeRegex(term)}([^\\p{L}\\p{N}]|$)`, 'iu'),
);

export function assertPostContentAllowed(input: PostContentInput) {
  const text = [input.title, input.description, input.category]
    .filter((value): value is string => typeof value === 'string')
    .join(' ');

  if (text.trim().length === 0) return;

  if (offensiveRegexes.some((pattern) => pattern.test(text))) {
    throw new BadRequestException(
      'El anuncio contiene lenguaje ofensivo. Edita el texto para publicarlo.',
    );
  }

  if (illegalOfferPatterns.some((pattern) => pattern.test(text))) {
    throw new BadRequestException(
      'No se aceptan anuncios de servicios o productos ilegales en OZIRAF.',
    );
  }
}

export function assertUserTextAllowed(
  text: string | undefined,
  label = 'El texto',
) {
  if (!text || text.trim().length === 0) return;

  if (offensiveRegexes.some((pattern) => pattern.test(text))) {
    throw new BadRequestException(
      `${label} contiene lenguaje ofensivo. Edita el texto para enviarlo.`,
    );
  }
}

function escapeRegex(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
