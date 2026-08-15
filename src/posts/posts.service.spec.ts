import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { PostsService } from './posts.service';
import { PrismaService } from '../prisma/prisma.service';

describe('PostsService', () => {
  let service: PostsService;
  let prisma: {
    post: {
      count: jest.Mock;
      create: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
  };

  beforeEach(async () => {
    prisma = {
      post: {
        count: jest.fn(),
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PostsService,
        {
          provide: PrismaService,
          useValue: prisma,
        },
      ],
    }).compile();

    service = module.get<PostsService>(PostsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('finds posts owned by a user ordered by newest first', async () => {
    const posts = [
      {
        id: 'post-1',
        title: 'Servicio de arquitectura',
        userId: 'user-1',
      },
    ];
    prisma.post.findMany.mockResolvedValue(posts);
    prisma.post.count.mockResolvedValue(21);

    const result = await service.findMine('user-1', {
      page: 2,
      limit: 10,
    });

    expect(prisma.post.findMany).toHaveBeenCalledWith({
      where: {
        userId: 'user-1',
      },
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
      skip: 10,
      take: 10,
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(prisma.post.count).toHaveBeenCalledWith({
      where: {
        userId: 'user-1',
      },
    });
    expect(result).toEqual({
      data: posts,
      page: 2,
      limit: 10,
      total: 21,
      totalPages: 3,
    });
  });

  it('finds all posts with default pagination', async () => {
    prisma.post.findMany.mockResolvedValue([]);
    prisma.post.count.mockResolvedValue(0);

    const result = await service.findAll();

    expect(prisma.post.findMany).toHaveBeenCalledWith({
      where: {},
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
      skip: 0,
      take: 20,
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(prisma.post.count).toHaveBeenCalledWith({
      where: {},
    });
    expect(result).toEqual({
      data: [],
      page: 1,
      limit: 20,
      total: 0,
      totalPages: 0,
    });
  });

  it('searches posts with filters and pagination metadata', async () => {
    const posts = [
      {
        id: 'post-1',
        title: 'Servicio de arquitectura',
        userId: 'user-1',
      },
    ];
    prisma.post.findMany.mockResolvedValue(posts);
    prisma.post.count.mockResolvedValue(1);

    const result = await service.search({
      q: 'arquitectura',
      city: 'Guadalajara',
      page: 1,
      limit: 10,
    });

    expect(prisma.post.count).toHaveBeenCalledWith({
      where: expect.objectContaining({
        status: 'ACTIVE',
        city: {
          contains: 'Guadalajara',
          mode: 'insensitive',
        },
      }),
    });
    expect(result).toEqual({
      data: posts,
      page: 1,
      limit: 10,
      total: 1,
      totalPages: 1,
    });
  });

  it('finds one post by id', async () => {
    const post = {
      id: 'post-1',
      title: 'Servicio de arquitectura',
      userId: 'user-1',
    };
    prisma.post.findUnique.mockResolvedValue(post);

    const result = await service.findOne('post-1');

    expect(prisma.post.findUnique).toHaveBeenCalledWith({
      where: {
        id: 'post-1',
      },
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
    });
    expect(result).toBe(post);
  });

  it('rejects missing posts by id', async () => {
    prisma.post.findUnique.mockResolvedValue(null);

    await expect(service.findOne('post-1')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('updates a post when it belongs to the user', async () => {
    const existingPost = {
      id: 'post-1',
      title: 'Servicio de arquitectura',
      userId: 'user-1',
    };
    const updatedPost = {
      ...existingPost,
      title: 'Servicio actualizado',
    };
    prisma.post.findUnique.mockResolvedValue(existingPost);
    prisma.post.update.mockResolvedValue(updatedPost);

    const result = await service.update('post-1', 'user-1', {
      title: 'Servicio actualizado',
    });

    expect(prisma.post.update).toHaveBeenCalledWith({
      where: {
        id: 'post-1',
      },
      data: {
        title: 'Servicio actualizado',
      },
    });
    expect(result).toBe(updatedPost);
  });

  it('rejects updates for missing posts', async () => {
    prisma.post.findUnique.mockResolvedValue(null);

    await expect(
      service.update('post-1', 'user-1', {
        title: 'Servicio actualizado',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('rejects updates from users who do not own the post', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-1',
      userId: 'owner-1',
    });

    await expect(
      service.update('post-1', 'user-1', {
        title: 'Servicio actualizado',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
