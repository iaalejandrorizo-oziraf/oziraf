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
    createPasswordResetToken: jest.Mock;
    findPasswordResetToken: jest.Mock;
    markPasswordResetTokenUsed: jest.Mock;
    createEmailVerificationToken: jest.Mock;
    findEmailVerificationToken: jest.Mock;
    markEmailVerificationTokenUsed: jest.Mock;
    markEmailVerified: jest.Mock;
    updatePassword: jest.Mock;
  };

  beforeEach(async () => {
    usersService = {
      create: jest.fn(),
      findByEmail: jest.fn(),
      findPrivateById: jest.fn(),
      createPasswordResetToken: jest.fn(),
      findPasswordResetToken: jest.fn(),
      markPasswordResetTokenUsed: jest.fn(),
      createEmailVerificationToken: jest.fn(),
      findEmailVerificationToken: jest.fn(),
      markEmailVerificationTokenUsed: jest.fn(),
      markEmailVerified: jest.fn(),
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

  it('rejects login for inactive users', async () => {
    usersService.findByEmail.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      password: await bcrypt.hash('Password123', 10),
      status: 'SUSPENDED',
    });

    await expect(
      service.login({
        email: 'user@example.com',
        password: 'Password123',
      }),
    ).rejects.toThrow('La cuenta no está activa');
  });

  it('creates password reset tokens for active users', async () => {
    usersService.findByEmail.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      status: 'ACTIVE',
    });
    usersService.createPasswordResetToken.mockResolvedValue({
      id: 'reset-token-id',
    });

    const result = await service.requestPasswordReset({
      email: 'user@example.com',
    });

    expect(usersService.createPasswordResetToken).toHaveBeenCalledWith(
      'user-1',
      expect.any(String),
      expect.any(Date),
    );
    expect(result).toHaveProperty('resetToken');
  });

  it('confirms valid password reset tokens', async () => {
    usersService.findPasswordResetToken.mockResolvedValue({
      id: 'reset-token-id',
      userId: 'user-1',
      usedAt: null,
      expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      user: {
        status: 'ACTIVE',
      },
    });
    usersService.updatePassword.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
    });
    usersService.markPasswordResetTokenUsed.mockResolvedValue({
      id: 'reset-token-id',
    });

    const result = await service.confirmPasswordReset({
      token: 'reset-token',
      newPassword: 'NewPassword123',
    });

    expect(usersService.updatePassword).toHaveBeenCalledWith(
      'user-1',
      expect.any(String),
    );
    expect(usersService.markPasswordResetTokenUsed).toHaveBeenCalledWith(
      'reset-token-id',
    );
    expect(result).not.toHaveProperty('password');
  });

  it('creates email verification tokens for active unverified users', async () => {
    usersService.findPrivateById.mockResolvedValue({
      id: 'user-1',
      status: 'ACTIVE',
      emailVerified: false,
    });
    usersService.createEmailVerificationToken.mockResolvedValue({
      id: 'verification-token-id',
    });

    const result = await service.requestEmailVerification('user-1');

    expect(usersService.createEmailVerificationToken).toHaveBeenCalledWith(
      'user-1',
      expect.any(String),
      expect.any(Date),
    );
    expect(result).toHaveProperty('verificationToken');
  });

  it('confirms valid email verification tokens', async () => {
    usersService.findEmailVerificationToken.mockResolvedValue({
      id: 'verification-token-id',
      userId: 'user-1',
      usedAt: null,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      user: {
        status: 'ACTIVE',
      },
    });
    usersService.markEmailVerified.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      emailVerified: true,
    });
    usersService.markEmailVerificationTokenUsed.mockResolvedValue({
      id: 'verification-token-id',
    });

    const result = await service.confirmEmailVerification({
      token: 'verification-token',
    });

    expect(usersService.markEmailVerified).toHaveBeenCalledWith('user-1');
    expect(usersService.markEmailVerificationTokenUsed).toHaveBeenCalledWith(
      'verification-token-id',
    );
    expect(result).toHaveProperty('emailVerified', true);
    expect(result).not.toHaveProperty('password');
  });
});
