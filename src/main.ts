import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { setupApp } from './app.setup';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);

  setupApp(app);

  const port = configService.get<number>('PORT') ?? 3000;

  await app.listen(port);

  console.log(`🚀 OZIRAF API ejecutándose en http://localhost:${port}`);
}

bootstrap();
