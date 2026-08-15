import { Test, TestingModule } from '@nestjs/testing';
import { publicUserSelect, UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';

describe('UsersService', () => {
  let service: UsersService;
  let prisma: {
    passwordResetToken: {
      create: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
    };
    user: {
      count: jest.Mock;
      create: jest.Mock;
      findMany: jest.Mock;
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
      passwordResetToken: {
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      user: {
        count: jest.fn(),
        create: jest.fn(),
        findMany: jest.fn(),
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

  it('finds users for admins with pagination and filters', async () => {
    prisma.user.findMany.mockResolvedValue([publicUser]);
    prisma.user.count.mockResolvedValue(1);

    const result = await service.findAllForAdmin({
      page: 1,
      limit: 10,
      status: 'ACTIVE',
      role: 'USER',
    });

    expect(prisma.user.findMany).toHaveBeenCalledWith({
      where: {
        status: 'ACTIVE',
        role: 'USER',
      },
      select: publicUserSelect,
      skip: 0,
      take: 10,
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(result).toEqual({
      data: [publicUser],
      page: 1,
      limit: 10,
      total: 1,
      totalPages: 1,
    });
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

  it('finds private users by id with password available', async () => {
    const privateUser = {
      ...publicUser,
      password: 'hashed-password',
    };
    prisma.user.findUnique.mockResolvedValue(privateUser);

    const result = await service.findPrivateById('user-1');

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: {
        id: 'user-1',
      },
    });
    expect(result).toHaveProperty('password');
  });

  it('updates passwords with the public user selection', async () => {
    prisma.user.update.mockResolvedValue(publicUser);

    const result = await service.updatePassword('user-1', 'new-hash');

    expect(prisma.user.update).toHaveBeenCalledWith({
      where: {
        id: 'user-1',
      },
      data: {
        password: 'new-hash',
      },
      select: publicUserSelect,
    });
    expect(result).not.toHaveProperty('password');
  });

  it('creates password reset tokens', async () => {
    const expiresAt = new Date('2026-01-01T01:00:00.000Z');
    prisma.passwordResetToken.create.mockResolvedValue({
      id: 'reset-token-id',
      userId: 'user-1',
      tokenHash: 'token-hash',
      expiresAt,
    });

    const result = await service.createPasswordResetToken(
      'user-1',
      'token-hash',
      expiresAt,
    );

    expect(prisma.passwordResetToken.create).toHaveBeenCalledWith({
      data: {
        userId: 'user-1',
        tokenHash: 'token-hash',
        expiresAt,
      },
    });
    expect(result).toHaveProperty('tokenHash', 'token-hash');
  });

  it('finds password reset tokens by hash', async () => {
    prisma.passwordResetToken.findUnique.mockResolvedValue({
      id: 'reset-token-id',
      tokenHash: 'token-hash',
    });

    const result = await service.findPasswordResetToken('token-hash');

    expect(prisma.passwordResetToken.findUnique).toHaveBeenCalledWith({
      where: {
        tokenHash: 'token-hash',
      },
      include: {
        user: true,
      },
    });
    expect(result).toHaveProperty('tokenHash', 'token-hash');
  });

  it('marks password reset tokens as used', async () => {
    prisma.passwordResetToken.update.mockResolvedValue({
      id: 'reset-token-id',
      usedAt: new Date('2026-01-01T01:00:00.000Z'),
    });

    const result = await service.markPasswordResetTokenUsed('reset-token-id');

    expect(prisma.passwordResetToken.update).toHaveBeenCalledWith({
      where: {
        id: 'reset-token-id',
      },
      data: {
        usedAt: expect.any(Date),
      },
    });
    expect(result).toHaveProperty('usedAt');
  });

  it('updates user status with the public user selection', async () => {
    prisma.user.update.mockResolvedValue({
      ...publicUser,
      status: 'SUSPENDED',
    });

    const result = await service.updateStatus('user-1', {
      status: 'SUSPENDED',
    });

    expect(prisma.user.update).toHaveBeenCalledWith({
      where: {
        id: 'user-1',
      },
      data: {
        status: 'SUSPENDED',
      },
      select: publicUserSelect,
    });
    expect(result).not.toHaveProperty('password');
  });
});
