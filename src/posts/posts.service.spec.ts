import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
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

  const expectedPostInclude = {
    user: {
      select: {
        id: true,
        firstName: true,
        lastName: true,
        profession: true,
        city: true,
        state: true,
        profilePhoto: true,
        phone: true,
        whatsapp: true,
        instagramUrl: true,
        facebookUrl: true,
        websiteUrl: true,
      },
    },
    reviews: {
      select: {
        rating: true,
      },
    },
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
      sortBy: 'price',
      sortOrder: 'asc',
      status: 'INACTIVE',
    });

    expect(prisma.post.findMany).toHaveBeenCalledWith({
      where: {
        userId: 'user-1',
        status: 'INACTIVE',
      },
      include: expectedPostInclude,
      skip: 10,
      take: 10,
      orderBy: {
        price: 'asc',
      },
    });
    expect(prisma.post.count).toHaveBeenCalledWith({
      where: {
        userId: 'user-1',
        status: 'INACTIVE',
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
      where: {
        status: 'ACTIVE',
      },
      include: expectedPostInclude,
      skip: 0,
      take: 20,
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(prisma.post.count).toHaveBeenCalledWith({
      where: {
        status: 'ACTIVE',
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

  it('returns active and inactive post stats for a user', async () => {
    prisma.post.count.mockResolvedValueOnce(2).mockResolvedValueOnce(1);

    const result = await service.findMyStats('user-1');

    expect(prisma.post.count).toHaveBeenNthCalledWith(1, {
      where: {
        userId: 'user-1',
        status: 'ACTIVE',
      },
    });
    expect(prisma.post.count).toHaveBeenNthCalledWith(2, {
      where: {
        userId: 'user-1',
        status: 'INACTIVE',
      },
    });
    expect(result).toEqual({
      active: 2,
      inactive: 1,
      total: 3,
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
      minPrice: 1000,
      maxPrice: 3000,
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
        price: {
          gte: 1000,
          lte: 3000,
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

  it('rejects search when min price is greater than max price', async () => {
    await expect(
      service.search({
        minPrice: 5000,
        maxPrice: 1000,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('returns available filters from active posts', async () => {
    prisma.post.findMany
      .mockResolvedValueOnce([{ category: 'Arquitectura' }])
      .mockResolvedValueOnce([{ country: 'Mexico' }])
      .mockResolvedValueOnce([{ state: 'Jalisco' }])
      .mockResolvedValueOnce([{ city: 'Guadalajara' }]);

    const result = await service.findFilters();

    expect(prisma.post.findMany).toHaveBeenNthCalledWith(1, {
      where: {
        status: 'ACTIVE',
      },
      distinct: ['category'],
      select: {
        category: true,
      },
      orderBy: {
        category: 'asc',
      },
    });
    expect(result).toEqual({
      categories: ['Arquitectura'],
      countries: ['Mexico'],
      states: ['Jalisco'],
      cities: ['Guadalajara'],
    });
  });

  it('finds posts for admins with pagination and status filters', async () => {
    const posts = [
      {
        id: 'post-1',
        title: 'Servicio de arquitectura',
        status: 'INACTIVE',
      },
    ];
    prisma.post.findMany.mockResolvedValue(posts);
    prisma.post.count.mockResolvedValue(1);

    const result = await service.findAllForAdmin({
      page: 1,
      limit: 10,
      status: 'INACTIVE',
      sortBy: 'createdAt',
      sortOrder: 'desc',
    });

    expect(prisma.post.findMany).toHaveBeenCalledWith({
      where: {
        status: 'INACTIVE',
      },
      include: expectedPostInclude,
      skip: 0,
      take: 10,
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(prisma.post.count).toHaveBeenCalledWith({
      where: {
        status: 'INACTIVE',
      },
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
      include: expectedPostInclude,
    });
    expect(result).toBe(post);
  });

  it('rejects missing posts by id', async () => {
    prisma.post.findUnique.mockResolvedValue(null);

    await expect(service.findOne('post-1')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('rejects deleted posts by id', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-1',
      status: 'DELETED',
    });

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
      include: expectedPostInclude,
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

  it('rejects updates for deleted posts', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-1',
      userId: 'user-1',
      status: 'DELETED',
    });

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

  it('updates a post status when it belongs to the user', async () => {
    const existingPost = {
      id: 'post-1',
      status: 'ACTIVE',
      userId: 'user-1',
    };
    const updatedPost = {
      ...existingPost,
      status: 'INACTIVE',
    };
    prisma.post.findUnique.mockResolvedValue(existingPost);
    prisma.post.update.mockResolvedValue(updatedPost);

    const result = await service.updateStatus('post-1', 'user-1', {
      status: 'INACTIVE',
    });

    expect(prisma.post.update).toHaveBeenCalledWith({
      where: {
        id: 'post-1',
      },
      data: {
        status: 'INACTIVE',
      },
      include: expectedPostInclude,
    });
    expect(result).toBe(updatedPost);
  });

  it('rejects status updates for deleted posts', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-1',
      status: 'DELETED',
      userId: 'user-1',
    });

    await expect(
      service.updateStatus('post-1', 'user-1', {
        status: 'ACTIVE',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('rejects status updates from users who do not own the post', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-1',
      status: 'ACTIVE',
      userId: 'owner-1',
    });

    await expect(
      service.updateStatus('post-1', 'user-1', {
        status: 'INACTIVE',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('updates a post status for admins', async () => {
    const existingPost = {
      id: 'post-1',
      status: 'ACTIVE',
      userId: 'user-1',
    };
    const updatedPost = {
      ...existingPost,
      status: 'DELETED',
    };
    prisma.post.findUnique.mockResolvedValue(existingPost);
    prisma.post.update.mockResolvedValue(updatedPost);

    const result = await service.updateStatusForAdmin('post-1', {
      status: 'DELETED',
    });

    expect(prisma.post.update).toHaveBeenCalledWith({
      where: {
        id: 'post-1',
      },
      data: {
        status: 'DELETED',
      },
      include: expectedPostInclude,
    });
    expect(result).toBe(updatedPost);
  });

  it('rejects admin status updates for missing posts', async () => {
    prisma.post.findUnique.mockResolvedValue(null);

    await expect(
      service.updateStatusForAdmin('post-1', {
        status: 'DELETED',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('soft deletes a post when it belongs to the user', async () => {
    const existingPost = {
      id: 'post-1',
      title: 'Servicio de arquitectura',
      userId: 'user-1',
    };
    const deletedPost = {
      ...existingPost,
      status: 'DELETED',
    };
    prisma.post.findUnique.mockResolvedValue(existingPost);
    prisma.post.update.mockResolvedValue(deletedPost);

    const result = await service.remove('post-1', 'user-1');

    expect(prisma.post.update).toHaveBeenCalledWith({
      where: {
        id: 'post-1',
      },
      data: {
        status: 'DELETED',
      },
    });
    expect(prisma.post.delete).not.toHaveBeenCalled();
    expect(result).toBe(deletedPost);
  });

  it('rejects deleting already deleted posts', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-1',
      userId: 'user-1',
      status: 'DELETED',
    });

    await expect(service.remove('post-1', 'user-1')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
