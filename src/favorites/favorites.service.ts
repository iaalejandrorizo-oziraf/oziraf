import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { ListFavoritesQueryDto } from './dto/list-favorites-query.dto';

function getPagination(options: ListFavoritesQueryDto = {}) {
  const page = Math.max(options.page ?? 1, 1);
  const limit = Math.min(Math.max(options.limit ?? 20, 1), 50);

  return {
    skip: (page - 1) * limit,
    take: limit,
  };
}

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
    return this.prisma.favorite.findMany({
      where: {
        userId,
      },
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
    });
  }
}
