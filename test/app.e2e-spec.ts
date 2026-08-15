import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

describe('AppController (e2e)', () => {
  let app: INestApplication<App>;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  it('/ (GET)', () => {
    return request(app.getHttpServer())
      .get('/')
      .expect(200)
      .expect({
        name: 'OZIRAF API',
        status: 'ok',
        version: '4.6',
      });
  });

  it('/health (GET)', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect({
        name: 'OZIRAF API',
        status: 'ok',
        version: '4.6',
      });
  });

  it('/auth/login is rate limited', async () => {
    const server = app.getHttpServer();

    for (let attempt = 0; attempt < 10; attempt += 1) {
      await request(server)
        .post('/auth/login')
        .send({
          email: `missing-${attempt}@example.com`,
          password: 'Password123',
        })
        .expect(401);
    }

    await request(server)
      .post('/auth/login')
      .send({
        email: 'missing-final@example.com',
        password: 'Password123',
      })
      .expect(429);
  });

  afterEach(async () => {
    await app.close();
  });
});
