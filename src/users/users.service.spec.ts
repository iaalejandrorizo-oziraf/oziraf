import { Test, TestingModule } from '@nestjs/testing';
import { publicUserSelect, UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';

describe('UsersService', () => {
  let service: UsersService;
  let prisma: {
    user: {
      create: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
    };
  };

  const publicUser = {
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
  };

  beforeEach(async () => {
    prisma = {
      user: {
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: PrismaService,
          useValue: prisma,
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('creates users with the public user selection', async () => {
    prisma.user.create.mockResolvedValue(publicUser);

    const result = await service.create({
      email: 'user@example.com',
      password: 'hashed-password',
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

    expect(prisma.user.create).toHaveBeenCalledWith({
      data: {
        email: 'user@example.com',
        password: 'hashed-password',
        firstName: 'Alejandro',
        lastName: 'Demo',
        phone: '+5215555555555',
        city: 'Guadalajara',
        state: 'Jalisco',
        neighborhood: 'Americana',
        profession: 'Arquitecto',
        description: 'Usuario de pruebas OZIRAF',
        profilePhoto: 'https://example.com/profile.jpg',
      },
      select: publicUserSelect,
    });
    expect(result).not.toHaveProperty('password');
  });

  it('finds users by id with the public user selection', async () => {
    prisma.user.findUnique.mockResolvedValue(publicUser);

    const result = await service.findById('user-1');

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: {
        id: 'user-1',
      },
      select: publicUserSelect,
    });
    expect(result).not.toHaveProperty('password');
  });

  it('updates profiles with the public user selection', async () => {
    prisma.user.update.mockResolvedValue({
      ...publicUser,
      lastName: 'Actualizado',
    });

    const result = await service.updateProfile('user-1', {
      lastName: 'Actualizado',
    });

    expect(prisma.user.update).toHaveBeenCalledWith({
      where: {
        id: 'user-1',
      },
      data: {
        lastName: 'Actualizado',
      },
      select: publicUserSelect,
    });
    expect(result).not.toHaveProperty('password');
  });
});
