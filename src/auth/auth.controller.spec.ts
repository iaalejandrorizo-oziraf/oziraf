import { Test, TestingModule } from '@nestjs/testing';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

describe('AuthController', () => {
  let controller: AuthController;
  let authService: {
    register: jest.Mock;
    login: jest.Mock;
    changePassword: jest.Mock;
  };

  beforeEach(async () => {
    authService = {
      register: jest.fn(),
      login: jest.fn(),
      changePassword: jest.fn(),
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
});
