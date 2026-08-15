import { Test, TestingModule } from '@nestjs/testing';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

describe('AuthController', () => {
  let controller: AuthController;
  let authService: {
    register: jest.Mock;
    login: jest.Mock;
    changePassword: jest.Mock;
    requestPasswordReset: jest.Mock;
    confirmPasswordReset: jest.Mock;
    requestEmailVerification: jest.Mock;
    confirmEmailVerification: jest.Mock;
  };

  beforeEach(async () => {
    authService = {
      register: jest.fn(),
      login: jest.fn(),
      changePassword: jest.fn(),
      requestPasswordReset: jest.fn(),
      confirmPasswordReset: jest.fn(),
      requestEmailVerification: jest.fn(),
      confirmEmailVerification: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        {
          provide: AuthService,
          useValue: authService,
        },
      ],
    }).compile();

    controller = module.get<AuthController>(AuthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('changes the authenticated user password', async () => {
    const user = {
      id: 'user-1',
      email: 'user@example.com',
    };
    authService.changePassword.mockResolvedValue(user);

    const result = await controller.changePassword(
      {
        user: {
          userId: 'user-1',
        },
      },
      {
        currentPassword: 'Password123',
        newPassword: 'NewPassword123',
      },
    );

    expect(authService.changePassword).toHaveBeenCalledWith('user-1', {
      currentPassword: 'Password123',
      newPassword: 'NewPassword123',
    });
    expect(result).toBe(user);
  });

  it('requests password reset', async () => {
    const response = {
      message: 'ok',
      resetToken: 'reset-token',
    };
    authService.requestPasswordReset.mockResolvedValue(response);

    const result = await controller.requestPasswordReset({
      email: 'user@example.com',
    });

    expect(authService.requestPasswordReset).toHaveBeenCalledWith({
      email: 'user@example.com',
    });
    expect(result).toBe(response);
  });

  it('confirms password reset', async () => {
    const user = {
      id: 'user-1',
      email: 'user@example.com',
    };
    authService.confirmPasswordReset.mockResolvedValue(user);

    const result = await controller.confirmPasswordReset({
      token: 'reset-token',
      newPassword: 'NewPassword123',
    });

    expect(authService.confirmPasswordReset).toHaveBeenCalledWith({
      token: 'reset-token',
      newPassword: 'NewPassword123',
    });
    expect(result).toBe(user);
  });

  it('requests email verification for the authenticated user', async () => {
    const response = {
      message: 'ok',
      verificationToken: 'verification-token',
    };
    authService.requestEmailVerification.mockResolvedValue(response);

    const result = await controller.requestEmailVerification({
      user: {
        userId: 'user-1',
      },
    });

    expect(authService.requestEmailVerification).toHaveBeenCalledWith(
      'user-1',
    );
    expect(result).toBe(response);
  });

  it('confirms email verification', async () => {
    const user = {
      id: 'user-1',
      email: 'user@example.com',
      emailVerified: true,
    };
    authService.confirmEmailVerification.mockResolvedValue(user);

    const result = await controller.confirmEmailVerification({
      token: 'verification-token',
    });

    expect(authService.confirmEmailVerification).toHaveBeenCalledWith({
      token: 'verification-token',
    });
    expect(result).toBe(user);
  });
});
