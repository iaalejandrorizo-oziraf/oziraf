import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { FavoritesService } from './favorites.service';
import { PrismaService } from '../prisma/prisma.service';

describe('FavoritesService', () => {
  let service: FavoritesService;
  let prisma: {
    favorite: {
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

    prisma.post.findUnique.mockResolvedValue({ id: 'post-id' });
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
    prisma.post.findUnique.mockResolvedValue({ id: 'post-id' });
    prisma.favorite.findUnique.mockResolvedValue({ id: 'favorite-id' });

    await expect(service.create('user-id', 'post-id')).rejects.toBeInstanceOf(
      ConflictException,
    );
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
});
