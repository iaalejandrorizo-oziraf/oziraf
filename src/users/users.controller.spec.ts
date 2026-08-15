import { Test, TestingModule } from '@nestjs/testing';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

describe('UsersController', () => {
  let controller: UsersController;
  let usersService: {
    findAllForAdmin: jest.Mock;
    findById: jest.Mock;
    updateProfile: jest.Mock;
    updateStatus: jest.Mock;
  };

  beforeEach(async () => {
    usersService = {
      findAllForAdmin: jest.fn(),
      findById: jest.fn(),
      updateProfile: jest.fn(),
      updateStatus: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: usersService,
        },
      ],
    }).compile();

    controller = module.get<UsersController>(UsersController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('returns users for admins', async () => {
    const response = {
      data: [],
      page: 1,
      limit: 10,
      total: 0,
      totalPages: 0,
    };
    usersService.findAllForAdmin.mockResolvedValue(response);

    const result = await controller.findAllForAdmin({
      page: 1,
      limit: 10,
      status: 'ACTIVE',
      role: 'USER',
    });

    expect(usersService.findAllForAdmin).toHaveBeenCalledWith({
      page: 1,
      limit: 10,
      status: 'ACTIVE',
      role: 'USER',
    });
    expect(result).toBe(response);
  });

  it('updates user status for admins', async () => {
    const user = {
      id: 'user-1',
      status: 'SUSPENDED',
    };
    usersService.updateStatus.mockResolvedValue(user);

    const result = await controller.updateStatus('user-1', {
      status: 'SUSPENDED',
    });

    expect(usersService.updateStatus).toHaveBeenCalledWith('user-1', {
      status: 'SUSPENDED',
    });
    expect(result).toBe(user);
  });
});
