import {
  BadRequestException,
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
import { AdminListPostsQueryDto } from './dto/admin-list-posts-query.dto';
import { AdminUpdatePostStatusDto } from './dto/admin-update-post-status.dto';
import { CreatePostDto } from './dto/create-post.dto';
import { ListPostsQueryDto } from './dto/list-posts-query.dto';
import { MyPostsQueryDto } from './dto/my-posts-query.dto';
import { SearchPostsQueryDto } from './dto/search-posts-query.dto';
import { UpdatePostStatusDto } from './dto/update-post-status.dto';
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

type MediaUpload = {
  buffer: Buffer;
  mimetype: string;
  originalname: string;
  size: number;
};

function withRating<T extends { id: string; reviews?: { rating: number }[] }>(
  post: T,
) {
  if (post.reviews === undefined) {
    return post;
  }

  const reviews = post.reviews ?? [];
  const reviewCount = reviews.length;
  const averageRating =
    reviewCount === 0
      ? null
      : Number(
          (
            reviews.reduce((sum, review) => sum + review.rating, 0) /
            reviewCount
          ).toFixed(1),
        );

  return {
    ...post,
    reviews: undefined,
    averageRating,
    reviewCount,
  };
}

function withRatings<
  T extends { id: string; reviews?: { rating: number }[] },
>(posts: T[]) {
  return posts.map((post) => withRating(post));
}

function getPostOrderBy(options: ListPostsQueryDto = {}) {
  const sortBy = options.sortBy ?? 'createdAt';
  const sortOrder = options.sortOrder ?? 'desc';

  return {
    [sortBy]: sortOrder,
  };
}

@Injectable()
export class PostsService {
  constructor(private prisma: PrismaService) {}

  private async attachMediaMetadata<T extends { id: string }>(posts: T[]) {
    if (posts.length === 0) {
      return posts;
    }

    if (!this.prisma.postMedia) {
      return posts;
    }

    const media = await this.prisma.postMedia.findMany({
      where: {
        postId: {
          in: posts.map((post) => post.id),
        },
      },
      select: {
        id: true,
        postId: true,
        kind: true,
        mimeType: true,
        fileName: true,
        size: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    const byPost = new Map<string, typeof media>();
    for (const item of media) {
      const current = byPost.get(item.postId) ?? [];
      current.push(item);
      byPost.set(item.postId, current);
    }

    return posts.map((post) => ({
      ...post,
      media: byPost.get(post.id) ?? [],
    }));
  }

  // Crear publicación
  async create(userId: string, createPostDto: CreatePostDto) {
    const post = await this.prisma.post.create({
      data: {
        ...createPostDto,
        userId,
      },
      include: postUserInclude,
    });

    return {
      ...withRating(post),
      media: [],
    };
  }

  async addMedia(id: string, userId: string, file?: MediaUpload) {
    if (!file) {
      throw new BadRequestException('Selecciona una foto o video');
    }

    const post = await this.prisma.post.findUnique({
      where: { id },
      select: {
        id: true,
        userId: true,
        status: true,
      },
    });

    if (!post || post.status === 'DELETED') {
      throw new NotFoundException('La publicación no existe');
    }

    if (post.userId !== userId) {
      throw new ForbiddenException(
        'No tienes permiso para agregar archivos a esta publicación',
      );
    }

    const imageTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);
    const videoTypes = new Set([
      'video/mp4',
      'video/quicktime',
      'video/webm',
      'video/3gpp',
    ]);

    const kind = imageTypes.has(file.mimetype)
      ? 'IMAGE'
      : videoTypes.has(file.mimetype)
        ? 'VIDEO'
        : null;

    if (!kind) {
      throw new BadRequestException(
        'Formato no compatible. Usa JPEG, PNG, WebP, MP4, MOV, WebM o 3GP',
      );
    }

    if (kind === 'IMAGE' && file.size > 2_500_000) {
      throw new BadRequestException('Cada foto debe pesar máximo 2.5 MB');
    }

    if (kind === 'VIDEO' && file.size > 12_000_000) {
      throw new BadRequestException('El video debe pesar máximo 12 MB');
    }

    const existing = await this.prisma.postMedia.findMany({
      where: { postId: id },
      select: { kind: true },
    });

    if (existing.length >= 5) {
      throw new BadRequestException(
        'Cada anuncio puede tener hasta 4 fotos y 1 video',
      );
    }

    const imageCount = existing.filter((item) => item.kind === 'IMAGE').length;
    const videoCount = existing.filter((item) => item.kind === 'VIDEO').length;

    if (kind === 'IMAGE' && imageCount >= 4) {
      throw new BadRequestException('Cada anuncio puede tener hasta 4 fotos');
    }

    if (kind === 'VIDEO' && videoCount >= 1) {
      throw new BadRequestException('Cada anuncio puede tener hasta 1 video');
    }

    const created = await this.prisma.postMedia.create({
      data: {
        postId: id,
        kind,
        mimeType: file.mimetype,
        fileName: file.originalname || null,
        size: file.size,
        data: Uint8Array.from(file.buffer),
      },
      select: {
        id: true,
        postId: true,
        kind: true,
        mimeType: true,
        fileName: true,
        size: true,
        createdAt: true,
      },
    });

    return created;
  }

  async findMedia(mediaId: string) {
    const media = await this.prisma.postMedia.findUnique({
      where: { id: mediaId },
      select: {
        data: true,
        mimeType: true,
        size: true,
        post: {
          select: {
            status: true,
          },
        },
      },
    });

    if (!media || media.post.status === 'DELETED') {
      throw new NotFoundException('El archivo no existe');
    }

    return media;
  }

  // Obtener todas las publicaciones
  async findAll(options?: ListPostsQueryDto) {
    const where: Prisma.PostWhereInput = {
      status: 'ACTIVE',
    };
    const [posts, total] = await Promise.all([
      this.prisma.post.findMany({
        where,
        include: postUserInclude,
        ...getPagination(options),
        orderBy: getPostOrderBy(options),
      }),
      this.prisma.post.count({
        where,
      }),
    ]);

    const enriched = await this.attachMediaMetadata(withRatings(posts));
    return buildPaginatedResponse(enriched, total, options);
  }

  // Obtener publicaciones del usuario autenticado
  async findMine(userId: string, options?: MyPostsQueryDto) {
    const where: Prisma.PostWhereInput = {
      userId,
      status: options?.status ?? {
        not: 'DELETED',
      },
    };
    const [posts, total] = await Promise.all([
      this.prisma.post.findMany({
        where,
        include: postUserInclude,
        ...getPagination(options),
        orderBy: getPostOrderBy(options),
      }),
      this.prisma.post.count({
        where,
      }),
    ]);

    const enriched = await this.attachMediaMetadata(withRatings(posts));
    return buildPaginatedResponse(enriched, total, options);
  }

  async findMyStats(userId: string) {
    const [active, inactive] = await Promise.all([
      this.prisma.post.count({
        where: {
          userId,
          status: 'ACTIVE',
        },
      }),
      this.prisma.post.count({
        where: {
          userId,
          status: 'INACTIVE',
        },
      }),
    ]);

    return {
      active,
      inactive,
      total: active + inactive,
    };
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

  async findAllForAdmin(options?: AdminListPostsQueryDto) {
    const where: Prisma.PostWhereInput = {
      ...(options?.status && {
        status: options.status,
      }),
    };

    const [posts, total] = await Promise.all([
      this.prisma.post.findMany({
        where,
        include: postUserInclude,
        ...getPagination(options),
        orderBy: getPostOrderBy(options),
      }),
      this.prisma.post.count({
        where,
      }),
    ]);

    const enriched = await this.attachMediaMetadata(withRatings(posts));
    return buildPaginatedResponse(enriched, total, options);
  }

  // Obtener una publicación por ID
  async findOne(id: string) {
    const post = await this.prisma.post.findUnique({
      where: {
        id,
      },
      include: postUserInclude,
    });

    if (!post || post.status === 'DELETED') {
      throw new NotFoundException('La publicación no existe');
    }

    const [enriched] = await this.attachMediaMetadata([withRating(post)]);
    return enriched;
  }

  // Actualizar publicación
  async update(id: string, userId: string, data: UpdatePostDto) {
    const post = await this.prisma.post.findUnique({
      where: {
        id,
      },
    });

    if (!post || post.status === 'DELETED') {
      throw new NotFoundException('La publicación no existe');
    }

    if (post.userId !== userId) {
      throw new ForbiddenException(
        'No tienes permiso para editar esta publicación',
      );
    }

    const updated = await this.prisma.post.update({
      where: {
        id,
      },
      data,
      include: postUserInclude,
    });

    const [enriched] = await this.attachMediaMetadata([withRating(updated)]);
    return enriched;
  }

  async updateStatus(
    id: string,
    userId: string,
    updatePostStatusDto: UpdatePostStatusDto,
  ) {
    const post = await this.prisma.post.findUnique({
      where: {
        id,
      },
    });

    if (!post || post.status === 'DELETED') {
      throw new NotFoundException('La publicación no existe');
    }

    if (post.userId !== userId) {
      throw new ForbiddenException(
        'No tienes permiso para cambiar el estado de esta publicación',
      );
    }

    const updated = await this.prisma.post.update({
      where: {
        id,
      },
      data: {
        status: updatePostStatusDto.status,
      },
      include: postUserInclude,
    });

    const [enriched] = await this.attachMediaMetadata([withRating(updated)]);
    return enriched;
  }

  async updateStatusForAdmin(
    id: string,
    adminUpdatePostStatusDto: AdminUpdatePostStatusDto,
  ) {
    const post = await this.prisma.post.findUnique({
      where: {
        id,
      },
    });

    if (!post) {
      throw new NotFoundException('La publicación no existe');
    }

    const updated = await this.prisma.post.update({
      where: {
        id,
      },
      data: {
        status: adminUpdatePostStatusDto.status,
      },
      include: postUserInclude,
    });

    const [enriched] = await this.attachMediaMetadata([withRating(updated)]);
    return enriched;
  }

  // Eliminar publicación
  async remove(id: string, userId: string) {
    const post = await this.prisma.post.findUnique({
      where: {
        id,
      },
    });

    if (!post || post.status === 'DELETED') {
      throw new NotFoundException('La publicación no existe');
    }

    if (post.userId !== userId) {
      throw new ForbiddenException(
        'No tienes permiso para eliminar esta publicación',
      );
    }

    return this.prisma.post.update({
      where: {
        id,
      },
      data: {
        status: 'DELETED',
      },
    });
  }

  async search(filters: SearchPostsQueryDto) {
    const { q, category, country, state, city, minPrice, maxPrice } = filters;

    if (minPrice && maxPrice && minPrice > maxPrice) {
      throw new BadRequestException(
        'El precio mínimo no puede ser mayor al precio máximo',
      );
    }

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

      ...((minPrice || maxPrice) && {
        price: {
          ...(minPrice && {
            gte: minPrice,
          }),
          ...(maxPrice && {
            lte: maxPrice,
          }),
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
        orderBy: getPostOrderBy(filters),
      }),
      this.prisma.post.count({
        where,
      }),
    ]);

    const enriched = await this.attachMediaMetadata(withRatings(posts));
    return buildPaginatedResponse(enriched, total, filters);
  }
}
