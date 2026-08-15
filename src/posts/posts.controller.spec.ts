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
    const posts = [
      {
        id: 'post-1',
        title: 'Servicio de arquitectura',
        userId: 'user-1',
      },
    ];
    postsService.findMine.mockResolvedValue(posts);

    const result = await controller.findMine({
      user: {
        userId: 'user-1',
      },
    });

    expect(postsService.findMine).toHaveBeenCalledWith('user-1');
    expect(result).toBe(posts);
  });
});
