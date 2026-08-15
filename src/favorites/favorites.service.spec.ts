import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { FavoritesService } from './favorites.service';
import { PrismaService } from '../prisma/prisma.service';

describe('FavoritesService', () => {
  let service: FavoritesService;
  let prisma: {
    favorite: {
      count: jest.Mock;
      create: jest.Mock;
      delete: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
    };
    post: {
      findUnique: jest.Mock;
    };
  };

  beforeEach(async () => {
    prisma = {
      favorite: {
        count: jest.fn(),
        create: jest.fn(),
        delete: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
      },
      post: {
        findUnique: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FavoritesService,
        {
          provide: PrismaService,
          useValue: prisma,
        },
      ],
    }).compile();

    service = module.get<FavoritesService>(FavoritesService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('creates a favorite when the post exists and is not already saved', async () => {
    const favorite = {
      id: 'favorite-id',
      userId: 'user-id',
      postId: 'post-id',
    };

    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      userId: 'owner-id',
      status: 'ACTIVE',
    });
    prisma.favorite.findUnique.mockResolvedValue(null);
    prisma.favorite.create.mockResolvedValue(favorite);

    await expect(service.create('user-id', 'post-id')).resolves.toBe(favorite);
    expect(prisma.favorite.create).toHaveBeenCalledWith({
      data: {
        userId: 'user-id',
        postId: 'post-id',
      },
      include: {
        post: true,
      },
    });
  });

  it('rejects creating a favorite for a missing post', async () => {
    prisma.post.findUnique.mockResolvedValue(null);

    await expect(service.create('user-id', 'post-id')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('rejects duplicate favorites', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      userId: 'owner-id',
      status: 'ACTIVE',
    });
    prisma.favorite.findUnique.mockResolvedValue({ id: 'favorite-id' });

    await expect(service.create('user-id', 'post-id')).rejects.toBeInstanceOf(
      ConflictException,
    );
  });

  it('rejects creating a favorite for the user own post', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      userId: 'user-id',
      status: 'ACTIVE',
    });

    await expect(service.create('user-id', 'post-id')).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(prisma.favorite.findUnique).not.toHaveBeenCalled();
  });

  it('rejects creating a favorite for an inactive post', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      userId: 'owner-id',
      status: 'DELETED',
    });

    await expect(service.create('user-id', 'post-id')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(prisma.favorite.findUnique).not.toHaveBeenCalled();
  });

  it('removes an existing favorite', async () => {
    const favorite = {
      id: 'favorite-id',
      userId: 'user-id',
      postId: 'post-id',
    };

    prisma.favorite.findUnique.mockResolvedValue(favorite);
    prisma.favorite.delete.mockResolvedValue(favorite);

    await expect(service.remove('user-id', 'post-id')).resolves.toBe(favorite);
  });

  it('rejects removing a missing favorite', async () => {
    prisma.favorite.findUnique.mockResolvedValue(null);

    await expect(service.remove('user-id', 'post-id')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('returns true when a post is already a favorite', async () => {
    prisma.favorite.findUnique.mockResolvedValue({
      id: 'favorite-id',
      userId: 'user-id',
      postId: 'post-id',
    });

    await expect(service.isFavorite('user-id', 'post-id')).resolves.toEqual({
      isFavorite: true,
    });
  });

  it('returns false when a post is not a favorite', async () => {
    prisma.favorite.findUnique.mockResolvedValue(null);

    await expect(service.isFavorite('user-id', 'post-id')).resolves.toEqual({
      isFavorite: false,
    });
  });

  it('finds favorites with default pagination', async () => {
    prisma.favorite.findMany.mockResolvedValue([]);
    prisma.favorite.count.mockResolvedValue(0);

    const result = await service.findAll('user-id');

    expect(prisma.favorite.findMany).toHaveBeenCalledWith({
      where: {
        userId: 'user-id',
        post: {
          status: 'ACTIVE',
        },
      },
      include: {
        post: {
          include: {
            user: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                profession: true,
                city: true,
                state: true,
                profilePhoto: true,
              },
            },
          },
        },
      },
      skip: 0,
      take: 20,
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(prisma.favorite.count).toHaveBeenCalledWith({
      where: {
        userId: 'user-id',
        post: {
          status: 'ACTIVE',
        },
      },
    });
    expect(result).toEqual({
      data: [],
      page: 1,
      limit: 20,
      total: 0,
      totalPages: 0,
    });
  });
});
