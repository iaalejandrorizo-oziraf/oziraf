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
import { CreateUserReportDto } from './dto/create-user-report.dto';
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
    const [postReports, userReports] = await Promise.all([
      this.prisma.postReport.findMany({
        where: {
          reporterId,
        },
        include: {
          post: true,
        },
        orderBy: {
          createdAt: 'desc',
        },
      }),
      this.prisma.userReport.findMany({
        where: {
          reporterId,
        },
        include: {
          targetUser: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
              status: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
      }),
    ]);

    return [
      ...postReports.map((report) => ({ ...report, type: 'POST' })),
      ...userReports.map((report) => ({ ...report, type: 'USER' })),
    ].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async reportUser(
    targetUserId: string,
    reporterId: string,
    data: CreateUserReportDto,
  ) {
    const targetUser = await this.prisma.user.findUnique({
      where: {
        id: targetUserId,
      },
      select: {
        id: true,
        status: true,
      },
    });

    if (!targetUser || targetUser.status === 'SUSPENDED') {
      throw new NotFoundException('La cuenta no existe');
    }

    if (targetUserId === reporterId) {
      throw new ConflictException('No puedes reportar tu propia cuenta');
    }

    const existingReport = await this.prisma.userReport.findUnique({
      where: {
        targetUserId_reporterId: {
          targetUserId,
          reporterId,
        },
      },
    });

    if (existingReport) {
      throw new ConflictException('Ya reportaste esta cuenta');
    }

    return this.prisma.userReport.create({
      data: {
        targetUserId,
        reporterId,
        reason: data.reason,
        details: data.details,
      },
      include: {
        targetUser: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            status: true,
          },
        },
      },
    });
  }

  async findAll(options?: ListReportsQueryDto) {
    const where = {
      ...(options?.status && {
        status: options.status,
      }),
    };

    const [postReports, userReports, postTotal, userTotal] = await Promise.all([
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
      this.prisma.userReport.findMany({
        where,
        include: {
          targetUser: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
              status: true,
            },
          },
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
      this.prisma.postReport.count({ where }),
      this.prisma.userReport.count({ where }),
    ]);

    const reports = [
      ...postReports.map((report) => ({ ...report, type: 'POST' })),
      ...userReports.map((report) => ({ ...report, type: 'USER' })),
    ].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

    return buildPaginatedResponse(reports, postTotal + userTotal, options);
  }

  async updateStatus(id: string, data: UpdateReportStatusDto) {
    const postReport = await this.prisma.postReport.findUnique({
      where: {
        id,
      },
    });

    if (postReport) {
      return {
        ...(await this.prisma.postReport.update({
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
        })),
        type: 'POST',
      };
    }

    const userReport = await this.prisma.userReport.findUnique({
      where: {
        id,
      },
    });

    if (!userReport) {
      throw new NotFoundException('El reporte no existe');
    }

    return {
      ...(await this.prisma.userReport.update({
        where: {
          id,
        },
        data: {
          status: data.status,
        },
        include: {
          targetUser: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
              status: true,
            },
          },
          reporter: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
            },
          },
        },
      })),
      type: 'USER',
    };
  }
}
