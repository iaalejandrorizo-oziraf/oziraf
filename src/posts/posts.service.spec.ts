import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { PostsService } from './posts.service';
import { PrismaService } from '../prisma/prisma.service';

describe('PostsService', () => {
  let service: PostsService;
  let prisma: {
    post: {
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

    const result = await service.findMine('user-1');

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
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(result).toBe(posts);
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
