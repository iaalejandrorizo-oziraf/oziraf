import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  buildPaginatedResponse,
  getPagination,
} from '../common/utils/pagination.util';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePostReportDto } from './dto/create-post-report.dto';
import { ListReportsQueryDto } from './dto/list-reports-query.dto';
import { UpdateReportStatusDto } from './dto/update-report-status.dto';

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

  async findAll(options?: ListReportsQueryDto) {
    const where: Prisma.PostReportWhereInput = {
      ...(options?.status && {
        status: options.status,
      }),
    };

    const [reports, total] = await Promise.all([
      this.prisma.postReport.findMany({
        where,
        include: {
          post: true,
          reporter: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
            },
          },
        },
        ...getPagination(options),
        orderBy: {
          createdAt: 'desc',
        },
      }),
      this.prisma.postReport.count({
        where,
      }),
    ]);

    return buildPaginatedResponse(reports, total, options);
  }

  async updateStatus(id: string, data: UpdateReportStatusDto) {
    const report = await this.prisma.postReport.findUnique({
      where: {
        id,
      },
    });

    if (!report) {
      throw new NotFoundException('El reporte no existe');
    }

    return this.prisma.postReport.update({
      where: {
        id,
      },
      data: {
        status: data.status,
      },
      include: {
        post: true,
        reporter: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
          },
        },
      },
    });
  }
}
