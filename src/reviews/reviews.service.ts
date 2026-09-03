import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  buildPaginatedResponse,
  getPagination,
} from '../common/utils/pagination.util';
import { PrismaService } from '../prisma/prisma.service';
import { assertUserTextAllowed } from '../posts/post-content-policy';
import { CreateReviewDto } from './dto/create-review.dto';
import { ListReviewsQueryDto } from './dto/list-reviews-query.dto';

@Injectable()
export class ReviewsService {
  constructor(private prisma: PrismaService) {}

  async create(postId: string, authorId: string, data: CreateReviewDto) {
    assertUserTextAllowed(data.comment, 'El comentario');

    const post = await this.prisma.post.findUnique({
      where: {
        id: postId,
      },
    });

    if (!post || post.status !== 'ACTIVE') {
      throw new NotFoundException('La publicacion no existe');
    }

    if (post.userId === authorId) {
      throw new ForbiddenException('No puedes calificar tu propia publicacion');
    }

    const existingReview = await this.prisma.review.findUnique({
      where: {
        postId_authorId: {
          postId,
          authorId,
        },
      },
    });

    if (existingReview) {
      throw new ConflictException('Ya calificaste esta publicacion');
    }

    return this.prisma.review.create({
      data: {
        postId,
        authorId,
        rating: data.rating,
        comment: data.comment,
      },
      include: {
        author: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
          },
        },
      },
    });
  }

  async findByPost(postId: string, options?: ListReviewsQueryDto) {
    const where = {
      postId,
    };

    const [reviews, total] = await Promise.all([
      this.prisma.review.findMany({
        where,
        include: {
          author: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
            },
          },
        },
        ...getPagination(options),
        orderBy: {
          createdAt: 'desc',
        },
      }),
      this.prisma.review.count({
        where,
      }),
    ]);

    return buildPaginatedResponse(reviews, total, options);
  }
}
