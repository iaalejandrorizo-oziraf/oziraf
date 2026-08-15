import { Test, TestingModule } from '@nestjs/testing';
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
});
