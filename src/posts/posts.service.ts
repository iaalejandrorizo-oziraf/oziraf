import {
  Injectable,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CreatePostDto } from './dto/create-post.dto';
import { ListPostsQueryDto } from './dto/list-posts-query.dto';
import { SearchPostsQueryDto } from './dto/search-posts-query.dto';
import { UpdatePostDto } from './dto/update-post.dto';

const postUserInclude = {
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
};

function getPagination(options: ListPostsQueryDto = {}) {
  const page = Math.max(options.page ?? 1, 1);
  const limit = Math.min(Math.max(options.limit ?? 20, 1), 50);

  return {
    skip: (page - 1) * limit,
    take: limit,
  };
}

@Injectable()
export class PostsService {
  constructor(private prisma: PrismaService) {}

  // Crear publicación
  async create(userId: string, createPostDto: CreatePostDto) {
    return this.prisma.post.create({
      data: {
        ...createPostDto,
        userId,
      },
    });
  }

  // Obtener todas las publicaciones
  async findAll(options?: ListPostsQueryDto) {
    return this.prisma.post.findMany({
      include: postUserInclude,
      ...getPagination(options),
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  // Obtener publicaciones del usuario autenticado
  async findMine(userId: string, options?: ListPostsQueryDto) {
    return this.prisma.post.findMany({
      where: {
        userId,
      },
      include: postUserInclude,
      ...getPagination(options),
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  // Obtener una publicación por ID
  async findOne(id: string) {
    const post = await this.prisma.post.findUnique({
      where: {
        id,
      },
      include: postUserInclude,
    });

    if (!post) {
      throw new NotFoundException('La publicación no existe');
    }

    return post;
  }

  // Actualizar publicación
  async update(id: string, userId: string, data: UpdatePostDto) {
    const post = await this.prisma.post.findUnique({
      where: {
        id,
      },
    });

    if (!post) {
      throw new NotFoundException('La publicación no existe');
    }

    if (post.userId !== userId) {
      throw new ForbiddenException(
        'No tienes permiso para editar esta publicación',
      );
    }

    return this.prisma.post.update({
      where: {
        id,
      },
      data,
    });
  }

  // Eliminar publicación
  async remove(id: string, userId: string) {
    const post = await this.prisma.post.findUnique({
      where: {
        id,
      },
    });

    if (!post) {
      throw new NotFoundException('La publicación no existe');
    }

    if (post.userId !== userId) {
      throw new ForbiddenException(
        'No tienes permiso para eliminar esta publicación',
      );
    }

    return this.prisma.post.delete({
      where: {
        id,
      },
    });
  }
  async search(filters: SearchPostsQueryDto) {
    const { q, category, country, state, city } = filters;

    return this.prisma.post.findMany({
      where: {
        status: 'ACTIVE',

        ...(category && {
          category: {
            contains: category,
            mode: 'insensitive',
          },
        }),

        ...(country && {
          country: {
            contains: country,
            mode: 'insensitive',
          },
        }),

        ...(state && {
          state: {
            contains: state,
            mode: 'insensitive',
          },
        }),

        ...(city && {
          city: {
            contains: city,
            mode: 'insensitive',
          },
        }),

        ...(q && {
          OR: [
            {
              title: {
                contains: q,
                mode: 'insensitive',
              },
            },
            {
              description: {
                contains: q,
                mode: 'insensitive',
              },
            },
          ],
        }),
      },

      include: postUserInclude,

      ...getPagination(filters),

      orderBy: {
        createdAt: 'desc',
      },
    });
  }
}
