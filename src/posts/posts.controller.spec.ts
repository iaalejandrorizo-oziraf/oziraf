import { Test, TestingModule } from '@nestjs/testing';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';

describe('PostsController', () => {
  let controller: PostsController;
  let postsService: {
    create: jest.Mock;
    findAll: jest.Mock;
    findMine: jest.Mock;
    findOne: jest.Mock;
    update: jest.Mock;
    remove: jest.Mock;
    search: jest.Mock;
  };

  beforeEach(async () => {
    postsService = {
      create: jest.fn(),
      findAll: jest.fn(),
      findMine: jest.fn(),
      findOne: jest.fn(),
      update: jest.fn(),
      remove: jest.fn(),
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
      },
    );

    expect(postsService.findMine).toHaveBeenCalledWith('user-1', {
      page: 2,
      limit: 10,
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
      page: 2,
      limit: 10,
    });

    expect(postsService.search).toHaveBeenCalledWith({
      q: 'arquitectura',
      city: 'Guadalajara',
      page: 2,
      limit: 10,
    });
    expect(result).toBe(response);
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
});
