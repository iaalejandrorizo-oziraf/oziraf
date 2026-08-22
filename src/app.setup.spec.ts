import { ConfigService } from '@nestjs/config';
import { setupApp } from './app.setup';

describe('setupApp', () => {
  it('configures security, cors, validation and shutdown hooks', () => {
    const configService = {
      get: jest.fn().mockReturnValue('http://localhost:5173,http://localhost:3001'),
    };
    const app = {
      enableShutdownHooks: jest.fn(),
      enableCors: jest.fn(),
      get: jest.fn().mockReturnValue(configService),
      use: jest.fn(),
      useGlobalPipes: jest.fn(),
    };

    setupApp(app as never);

    expect(app.get).toHaveBeenCalledWith(ConfigService);
    expect(app.enableShutdownHooks).toHaveBeenCalled();
    expect(app.use).toHaveBeenCalled();
    expect(app.enableCors).toHaveBeenCalledWith({
  origin: [
    'http://localhost:5173',
    'http://localhost:3001',
    'http://127.0.0.1:8092',
    'http://localhost:8092',
    'http://100.112.136.50:8092',
  ],
  credentials: true,
});
    expect(app.useGlobalPipes).toHaveBeenCalled();
  });
});
