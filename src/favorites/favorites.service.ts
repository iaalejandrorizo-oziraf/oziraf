import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import {
  buildPaginatedResponse,
  getPagination,
} from '../common/utils/pagination.util';
import { PrismaService } from '../prisma/prisma.service';
import { ListFavoritesQueryDto } from './dto/list-favorites-query.dto';

@Injectable()
export class FavoritesService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, postId: string) {
    const post = await this.prisma.post.findUnique({
      where: {
        id: postId,
      },
    });

    if (!post) {
      throw new NotFoundException('La publicación no existe');
    }

    const favorite = await this.prisma.favorite.findUnique({
      where: {
        userId_postId: {
          userId,
          postId,
        },
      },
    });

    if (favorite) {
      throw new ConflictException('La publicación ya está en favoritos');
    }

    return this.prisma.favorite.create({
      data: {
        userId,
        postId,
      },
      include: {
        post: true,
      },
    });
  }

  async remove(userId: string, postId: string) {
    const favorite = await this.prisma.favorite.findUnique({
      where: {
        userId_postId: {
          userId,
          postId,
        },
      },
    });

    if (!favorite) {
      throw new NotFoundException('El favorito no existe');
    }

    return this.prisma.favorite.delete({
      where: {
        userId_postId: {
          userId,
          postId,
        },
      },
    });
  }

  async isFavorite(userId: string, postId: string) {
    const favorite = await this.prisma.favorite.findUnique({
      where: {
        userId_postId: {
          userId,
          postId,
        },
      },
    });

    return {
      isFavorite: Boolean(favorite),
    };
  }

  async findAll(userId: string, options?: ListFavoritesQueryDto) {
    const where = {
      userId,
    };

    const [favorites, total] = await Promise.all([
      this.prisma.favorite.findMany({
        where,
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
        ...getPagination(options),
        orderBy: {
          createdAt: 'desc',
        },
      }),
      this.prisma.favorite.count({
        where,
      }),
    ]);

    return buildPaginatedResponse(favorites, total, options);
  }
}
