import {
  Injectable,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import {
  buildPaginatedResponse,
  getPagination,
} from '../common/utils/pagination.util';
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
    const where: Prisma.PostWhereInput = {};
    const [posts, total] = await Promise.all([
      this.prisma.post.findMany({
        where,
        include: postUserInclude,
        ...getPagination(options),
        orderBy: {
          createdAt: 'desc',
        },
      }),
      this.prisma.post.count({
        where,
      }),
    ]);

    return buildPaginatedResponse(posts, total, options);
  }

  // Obtener publicaciones del usuario autenticado
  async findMine(userId: string, options?: ListPostsQueryDto) {
    const where: Prisma.PostWhereInput = {
      userId,
    };
    const [posts, total] = await Promise.all([
      this.prisma.post.findMany({
        where,
        include: postUserInclude,
        ...getPagination(options),
        orderBy: {
          createdAt: 'desc',
        },
      }),
      this.prisma.post.count({
        where,
      }),
    ]);

    return buildPaginatedResponse(posts, total, options);
  }

  async findFilters() {
    const [categories, countries, states, cities] = await Promise.all([
      this.prisma.post.findMany({
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
      }),
      this.prisma.post.findMany({
        where: {
          status: 'ACTIVE',
        },
        distinct: ['country'],
        select: {
          country: true,
        },
        orderBy: {
          country: 'asc',
        },
      }),
      this.prisma.post.findMany({
        where: {
          status: 'ACTIVE',
        },
        distinct: ['state'],
        select: {
          state: true,
        },
        orderBy: {
          state: 'asc',
        },
      }),
      this.prisma.post.findMany({
        where: {
          status: 'ACTIVE',
        },
        distinct: ['city'],
        select: {
          city: true,
        },
        orderBy: {
          city: 'asc',
        },
      }),
    ]);

    return {
      categories: categories.map((post) => post.category),
      countries: countries.map((post) => post.country),
      states: states.map((post) => post.state),
      cities: cities.map((post) => post.city),
    };
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

    const where: Prisma.PostWhereInput = {
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
    };

    const [posts, total] = await Promise.all([
      this.prisma.post.findMany({
        where,
        include: postUserInclude,
        ...getPagination(filters),
        orderBy: {
          createdAt: 'desc',
        },
      }),
      this.prisma.post.count({
        where,
      }),
    ]);

    return buildPaginatedResponse(posts, total, filters);
  }
}
