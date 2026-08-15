import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateContactLeadDto } from './dto/create-contact-lead.dto';

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

  async findReceived(ownerId: string) {
    return this.prisma.contactLead.findMany({
      where: {
        ownerId,
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
      orderBy: {
        createdAt: 'desc',
      },
    });
  }
}
