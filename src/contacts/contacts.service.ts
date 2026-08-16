import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  buildPaginatedResponse,
  getPagination,
} from '../common/utils/pagination.util';
import { PrismaService } from '../prisma/prisma.service';
import { CreateContactLeadDto } from './dto/create-contact-lead.dto';
import { ListContactLeadsQueryDto } from './dto/list-contact-leads-query.dto';
import { UpdateContactLeadStatusDto } from './dto/update-contact-lead-status.dto';

@Injectable()
export class ContactsService {
  constructor(private prisma: PrismaService) {}

  async create(postId: string, senderId: string, data: CreateContactLeadDto) {
    const post = await this.prisma.post.findUnique({
      where: {
        id: postId,
      },
    });

    if (!post || post.status !== 'ACTIVE') {
      throw new NotFoundException('La publicación no existe');
    }

    if (post.userId === senderId) {
      throw new ConflictException('No puedes contactar tu propia publicación');
    }

    return this.prisma.contactLead.create({
      data: {
        postId,
        senderId,
        ownerId: post.userId,
        message: data.message,
      },
      include: {
        post: true,
        sender: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
          },
        },
      },
    });
  }

  async findReceived(ownerId: string, options?: ListContactLeadsQueryDto) {
    const where: Prisma.ContactLeadWhereInput = {
      ownerId,
      ...(options?.status && {
        status: options.status,
      }),
    };

    const [leads, total] = await Promise.all([
      this.prisma.contactLead.findMany({
        where,
        include: {
          post: true,
          sender: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
              phone: true,
            },
          },
        },
        ...getPagination(options),
        orderBy: {
          createdAt: 'desc',
        },
      }),
      this.prisma.contactLead.count({
        where,
      }),
    ]);

    return buildPaginatedResponse(leads, total, options);
  }

  async findSent(senderId: string, options?: ListContactLeadsQueryDto) {
    const where: Prisma.ContactLeadWhereInput = {
      senderId,
      ...(options?.status && {
        status: options.status,
      }),
    };

    const [leads, total] = await Promise.all([
      this.prisma.contactLead.findMany({
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
                  phone: true,
                  whatsapp: true,
                },
              },
            },
          },
          owner: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
              phone: true,
            },
          },
        },
        ...getPagination(options),
        orderBy: {
          createdAt: 'desc',
        },
      }),
      this.prisma.contactLead.count({
        where,
      }),
    ]);

    return buildPaginatedResponse(leads, total, options);
  }

  async updateStatus(
    id: string,
    ownerId: string,
    data: UpdateContactLeadStatusDto,
  ) {
    const lead = await this.prisma.contactLead.findUnique({
      where: {
        id,
      },
    });

    if (!lead) {
      throw new NotFoundException('El contacto no existe');
    }

    if (lead.ownerId !== ownerId) {
      throw new ForbiddenException(
        'No tienes permiso para actualizar este contacto',
      );
    }

    return this.prisma.contactLead.update({
      where: {
        id,
      },
      data: {
        status: data.status,
      },
      include: {
        post: true,
        sender: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
          },
        },
      },
    });
  }
}
