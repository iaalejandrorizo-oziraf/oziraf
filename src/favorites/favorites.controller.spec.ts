import { Test, TestingModule } from '@nestjs/testing';
import { FavoritesController } from './favorites.controller';
import { FavoritesService } from './favorites.service';

describe('FavoritesController', () => {
  let controller: FavoritesController;
  let favoritesService: {
    create: jest.Mock;
    remove: jest.Mock;
    findAll: jest.Mock;
    isFavorite: jest.Mock;
  };

  beforeEach(async () => {
    favoritesService = {
      create: jest.fn(),
      remove: jest.fn(),
      findAll: jest.fn(),
      isFavorite: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [FavoritesController],
      providers: [
        {
          provide: FavoritesService,
          useValue: favoritesService,
        },
      ],
    }).compile();

    controller = module.get<FavoritesController>(FavoritesController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('returns favorite status for a post', async () => {
    favoritesService.isFavorite.mockResolvedValue({
      isFavorite: true,
    });

    const result = await controller.status(
      {
        user: {
          userId: 'user-id',
        },
      },
      {
        postId: 'post-id',
      },
    );

    expect(favoritesService.isFavorite).toHaveBeenCalledWith(
      'user-id',
      'post-id',
    );
    expect(result).toEqual({
      isFavorite: true,
    });
  });

  it('returns favorites for the authenticated user with pagination', async () => {
    const response = {
      data: [
        {
          id: 'favorite-id',
          userId: 'user-id',
          postId: 'post-id',
        },
      ],
      page: 2,
      limit: 10,
      total: 1,
      totalPages: 1,
    };
    favoritesService.findAll.mockResolvedValue(response);

    const result = await controller.findAll(
      {
        user: {
          userId: 'user-id',
        },
      },
      {
        page: 2,
        limit: 10,
      },
    );

    expect(favoritesService.findAll).toHaveBeenCalledWith('user-id', {
      page: 2,
      limit: 10,
    });
    expect(result).toBe(response);
  });
});
