import {
  Injectable,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CreatePostDto } from './dto/create-post.dto';

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
  async findAll() {
    return this.prisma.post.findMany({
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
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  // Obtener una publicación por ID
  async findOne(id: string) {
    return this.prisma.post.findUnique({
      where: {
        id,
      },
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
    });
  }

  // Actualizar publicación
  async update(
    id: string,
    userId: string,
    data: CreatePostDto,
  ) {
    const post = await this.prisma.post.findUnique({
      where: {
        id,
      },
    });

    if (!post) {
      throw new NotFoundException(
        'La publicación no existe',
      );
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
  async remove(
    id: string,
    userId: string,
  ) {
    const post = await this.prisma.post.findUnique({
      where: {
        id,
      },
    });

    if (!post) {
      throw new NotFoundException(
        'La publicación no existe',
      );
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
}