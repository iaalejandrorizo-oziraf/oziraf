import { Test, TestingModule } from '@nestjs/testing';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';

describe('PostsController', () => {
  let controller: PostsController;
  let postsService: {
    create: jest.Mock;
    findAll: jest.Mock;
    findFilters: jest.Mock;
    findMine: jest.Mock;
    findMyStats: jest.Mock;
    findAllForAdmin: jest.Mock;
    findOne: jest.Mock;
    findMedia: jest.Mock;
    update: jest.Mock;
    updateStatus: jest.Mock;
    updateStatusForAdmin: jest.Mock;
    remove: jest.Mock;
    removeMedia: jest.Mock;
    search: jest.Mock;
  };

  beforeEach(async () => {
    postsService = {
      create: jest.fn(),
      findAll: jest.fn(),
      findFilters: jest.fn(),
      findMine: jest.fn(),
      findMyStats: jest.fn(),
      findAllForAdmin: jest.fn(),
      findOne: jest.fn(),
      findMedia: jest.fn(),
      update: jest.fn(),
      updateStatus: jest.fn(),
      updateStatusForAdmin: jest.fn(),
      remove: jest.fn(),
      removeMedia: jest.fn(),
      search: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [PostsController],
      providers: [
        {
          provide: PostsService,
          useValue: postsService,
        },
      ],
    }).compile();

    controller = module.get<PostsController>(PostsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('returns posts for the authenticated user', async () => {
    const response = {
      data: [
        {
          id: 'post-1',
          title: 'Servicio de arquitectura',
          userId: 'user-1',
        },
      ],
      page: 2,
      limit: 10,
      total: 1,
      totalPages: 1,
    };
    postsService.findMine.mockResolvedValue(response);

    const result = await controller.findMine(
      {
        user: {
          userId: 'user-1',
        },
      },
      {
        page: 2,
        limit: 10,
        sortBy: 'price',
        sortOrder: 'asc',
        status: 'INACTIVE',
      },
    );

    expect(postsService.findMine).toHaveBeenCalledWith('user-1', {
      page: 2,
      limit: 10,
      sortBy: 'price',
      sortOrder: 'asc',
      status: 'INACTIVE',
    });
    expect(result).toBe(response);
  });

  it('passes pagination options to the posts list', async () => {
    const response = {
      data: [],
      page: 2,
      limit: 10,
      total: 0,
      totalPages: 0,
    };
    postsService.findAll.mockResolvedValue(response);

    const result = await controller.findAll({
      page: 2,
      limit: 10,
    });

    expect(postsService.findAll).toHaveBeenCalledWith({
      page: 2,
      limit: 10,
    });
    expect(result).toBe(response);
  });

  it('passes search filters and pagination options to the service', async () => {
    const response = {
      data: [],
      page: 2,
      limit: 10,
      total: 0,
      totalPages: 0,
    };
    postsService.search.mockResolvedValue(response);

    const result = await controller.search({
      q: 'arquitectura',
      city: 'Guadalajara',
      minPrice: 1000,
      maxPrice: 3000,
      page: 2,
      limit: 10,
    });

    expect(postsService.search).toHaveBeenCalledWith({
      q: 'arquitectura',
      city: 'Guadalajara',
      minPrice: 1000,
      maxPrice: 3000,
      page: 2,
      limit: 10,
    });
    expect(result).toBe(response);
  });

  it('returns available post filters', async () => {
    const filters = {
      categories: ['Arquitectura'],
      countries: ['Mexico'],
      states: ['Jalisco'],
      cities: ['Guadalajara'],
    };
    postsService.findFilters.mockResolvedValue(filters);

    const result = await controller.findFilters();

    expect(postsService.findFilters).toHaveBeenCalled();
    expect(result).toBe(filters);
  });

  it('returns stats for the authenticated user posts', async () => {
    const stats = {
      active: 2,
      inactive: 1,
      total: 3,
    };
    postsService.findMyStats.mockResolvedValue(stats);

    const result = await controller.findMyStats({
      user: {
        userId: 'user-1',
      },
    });

    expect(postsService.findMyStats).toHaveBeenCalledWith('user-1');
    expect(result).toBe(stats);
  });

  it('returns paginated posts for admins', async () => {
    const response = {
      data: [],
      page: 1,
      limit: 10,
      total: 0,
      totalPages: 0,
    };
    postsService.findAllForAdmin.mockResolvedValue(response);

    const result = await controller.findAllForAdmin({
      page: 1,
      limit: 10,
      status: 'INACTIVE',
    });

    expect(postsService.findAllForAdmin).toHaveBeenCalledWith({
      page: 1,
      limit: 10,
      status: 'INACTIVE',
    });
    expect(result).toBe(response);
  });

  it('updates a post status for admins', async () => {
    const post = {
      id: 'post-1',
      status: 'DELETED',
      userId: 'user-1',
    };
    postsService.updateStatusForAdmin.mockResolvedValue(post);

    const result = await controller.updateStatusForAdmin('post-1', {
      status: 'DELETED',
    });

    expect(postsService.updateStatusForAdmin).toHaveBeenCalledWith('post-1', {
      status: 'DELETED',
    });
    expect(result).toBe(post);
  });

  it('updates a post with partial data for the authenticated user', async () => {
    const post = {
      id: 'post-1',
      title: 'Servicio actualizado',
      userId: 'user-1',
    };
    postsService.update.mockResolvedValue(post);

    const result = await controller.update(
      'post-1',
      {
        user: {
          userId: 'user-1',
        },
      },
      {
        title: 'Servicio actualizado',
      },
    );

    expect(postsService.update).toHaveBeenCalledWith('post-1', 'user-1', {
      title: 'Servicio actualizado',
    });
    expect(result).toBe(post);
  });

  it('updates a post status for the authenticated user', async () => {
    const post = {
      id: 'post-1',
      status: 'INACTIVE',
      userId: 'user-1',
    };
    postsService.updateStatus.mockResolvedValue(post);

    const result = await controller.updateStatus(
      'post-1',
      {
        user: {
          userId: 'user-1',
        },
      },
      {
        status: 'INACTIVE',
      },
    );

    expect(postsService.updateStatus).toHaveBeenCalledWith('post-1', 'user-1', {
      status: 'INACTIVE',
    });
    expect(result).toBe(post);
  });

  it('removes media from a post for the authenticated user', async () => {
    postsService.removeMedia.mockResolvedValue({ id: 'media-1' });

    const result = await controller.removeMedia('post-1', 'media-1', {
      user: { userId: 'user-1' },
    });

    expect(postsService.removeMedia).toHaveBeenCalledWith(
      'post-1',
      'media-1',
      'user-1',
    );
    expect(result).toEqual({ id: 'media-1' });
  });

  it('allows browsers to stream media across the web and API origins', async () => {
    postsService.findMedia.mockResolvedValue({
      data: Buffer.from([1, 2, 3, 4]),
      mimeType: 'video/mp4',
    });
    const response = {
      setHeader: jest.fn(),
      status: jest.fn().mockReturnThis(),
      send: jest.fn(),
      end: jest.fn(),
    };

    await controller.getMedia('media-1', 'bytes=0-1', response as never);

    expect(response.setHeader).toHaveBeenCalledWith(
      'Cross-Origin-Resource-Policy',
      'cross-origin',
    );
    expect(response.setHeader).toHaveBeenCalledWith(
      'Access-Control-Expose-Headers',
      'Accept-Ranges, Content-Length, Content-Range',
    );
    expect(response.status).toHaveBeenCalledWith(206);
  });
});
