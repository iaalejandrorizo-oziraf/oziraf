import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePostReportDto } from './dto/create-post-report.dto';

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  async reportPost(
    postId: string,
    reporterId: string,
    data: CreatePostReportDto,
  ) {
    const post = await this.prisma.post.findUnique({
      where: {
        id: postId,
      },
    });

    if (!post || post.status !== 'ACTIVE') {
      throw new NotFoundException('La publicación no existe');
    }

    if (post.userId === reporterId) {
      throw new ConflictException('No puedes reportar tu propia publicación');
    }

    const existingReport = await this.prisma.postReport.findUnique({
      where: {
        postId_reporterId: {
          postId,
          reporterId,
        },
      },
    });

    if (existingReport) {
      throw new ConflictException('Ya reportaste esta publicación');
    }

    return this.prisma.postReport.create({
      data: {
        postId,
        reporterId,
        reason: data.reason,
        details: data.details,
      },
      include: {
        post: true,
      },
    });
  }

  async findMine(reporterId: string) {
    return this.prisma.postReport.findMany({
      where: {
        reporterId,
      },
      include: {
        post: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }
}
