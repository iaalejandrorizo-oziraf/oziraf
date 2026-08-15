import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
  let service: AuthService;
  let usersService: {
    create: jest.Mock;
    findByEmail: jest.Mock;
    findPrivateById: jest.Mock;
    updatePassword: jest.Mock;
  };

  beforeEach(async () => {
    usersService = {
      create: jest.fn(),
      findByEmail: jest.fn(),
      findPrivateById: jest.fn(),
      updatePassword: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: UsersService,
          useValue: usersService,
        },
        {
          provide: JwtService,
          useValue: {
            signAsync: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('registers users without returning a password', async () => {
    usersService.findByEmail.mockResolvedValue(null);
    usersService.create.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      firstName: 'Alejandro',
      lastName: 'Demo',
      phone: '+5215555555555',
      role: 'USER',
      createdAt: new Date('2026-01-01T00:00:00.000Z'),
      updatedAt: new Date('2026-01-01T00:00:00.000Z'),
      emailVerified: false,
      profilePhoto: 'https://example.com/profile.jpg',
      status: 'ACTIVE',
      city: 'Guadalajara',
      description: 'Usuario de pruebas OZIRAF',
      neighborhood: 'Americana',
      profession: 'Arquitecto',
      state: 'Jalisco',
    });

    const result = await service.register({
      email: 'user@example.com',
      password: 'Password123',
      firstName: 'Alejandro',
      lastName: 'Demo',
      phone: '+5215555555555',
      city: 'Guadalajara',
      state: 'Jalisco',
      neighborhood: 'Americana',
      profession: 'Arquitecto',
      description: 'Usuario de pruebas OZIRAF',
      profilePhoto: 'https://example.com/profile.jpg',
    });

    expect(result).not.toHaveProperty('password');
    expect(usersService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        email: 'user@example.com',
        firstName: 'Alejandro',
        lastName: 'Demo',
      }),
    );
    expect(usersService.create.mock.calls[0][0].password).not.toBe(
      'Password123',
    );
  });

  it('changes passwords without returning a password', async () => {
    usersService.findPrivateById.mockResolvedValue({
      id: 'user-1',
      password: await bcrypt.hash('Password123', 10),
    });
    usersService.updatePassword.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      firstName: 'Alejandro',
    });

    const result = await service.changePassword('user-1', {
      currentPassword: 'Password123',
      newPassword: 'NewPassword123',
    });

    expect(usersService.updatePassword).toHaveBeenCalledWith(
      'user-1',
      expect.any(String),
    );
    expect(result).not.toHaveProperty('password');
  });
});
