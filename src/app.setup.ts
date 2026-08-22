import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';

export function setupApp(app: INestApplication) {
  const configService = app.get(ConfigService);
  const corsOrigin = configService.get<string>('CORS_ORIGIN');

  const configuredOrigins = corsOrigin
    ? corsOrigin
        .split(',')
        .map((origin) => origin.trim())
        .filter(Boolean)
    : [];

  const localWebOrigins = [
    'http://127.0.0.1:8092',
    'http://localhost:8092',
    'http://100.112.136.50:8092',
  ];

  const allowedOrigins = [...new Set([...configuredOrigins, ...localWebOrigins])];

  app.enableShutdownHooks();
  app.use(helmet());

  app.enableCors({
    origin: allowedOrigins.length > 0 ? allowedOrigins : true,
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
}
