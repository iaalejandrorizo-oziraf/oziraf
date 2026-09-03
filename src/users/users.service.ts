import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  buildPaginatedResponse,
  getPagination,
} from '../common/utils/pagination.util';
import { PrismaService } from '../prisma/prisma.service';
import { ListUsersQueryDto } from './dto/list-users-query.dto';
import { UpdateUserBillingDto } from './dto/update-user-billing.dto';
import { UpdateUserStatusDto } from './dto/update-user-status.dto';

export const publicUserSelect = {
  id: true,
  email: true,
  firstName: true,
  lastName: true,
  phone: true,
  role: true,
  accountType: true,
  createdAt: true,
  updatedAt: true,
  emailVerified: true,
  profilePhoto: true,
  whatsapp: true,
  instagramUrl: true,
  facebookUrl: true,
  tiktokUrl: true,
  xUrl: true,
  websiteUrl: true,
  status: true,
  billingStatus: true,
  renewalDueAt: true,
  city: true,
  description: true,
  neighborhood: true,
  profession: true,
  state: true,
};

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async create(data: {
    email: string;
    password: string;
    firstName: string;
    lastName?: string;
    accountType?: string;
    phone?: string;
    city?: string;
    state?: string;
    neighborhood?: string;
    profession?: string;
    description?: string;
    profilePhoto?: string;
    whatsapp?: string;
    instagramUrl?: string;
    facebookUrl?: string;
    tiktokUrl?: string;
    xUrl?: string;
    websiteUrl?: string;
  }) {
    return this.prisma.user.create({
      data,
      select: publicUserSelect,
    });
  }

  async findByEmail(email: string) {
    return this.prisma.user.findUnique({
      where: {
        email,
      },
    });
  }

  async findAllForAdmin(options?: ListUsersQueryDto) {
    const where: Prisma.UserWhereInput = {
      ...(options?.status && {
        status: options.status,
      }),
      ...(options?.role && {
        role: options.role,
      }),
    };

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        select: publicUserSelect,
        ...getPagination(options),
        orderBy: {
          createdAt: 'desc',
        },
      }),
      this.prisma.user.count({
        where,
      }),
    ]);

    return buildPaginatedResponse(users, total, options);
  }

  async getAdminSummary() {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const [
      totalUsers,
      activeUsers,
      suspendedUsers,
      paidUsers,
      dueRenewals,
      overdueRenewals,
      newThisMonth,
      advertisers,
      requesters,
      activePosts,
      openPostReports,
      openUserReports,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { status: 'ACTIVE' } }),
      this.prisma.user.count({ where: { status: 'SUSPENDED' } }),
      this.prisma.user.count({ where: { billingStatus: 'PAID' } }),
      this.prisma.user.count({ where: { billingStatus: 'DUE' } }),
      this.prisma.user.count({
        where: {
          OR: [
            { billingStatus: 'OVERDUE' },
            { renewalDueAt: { lt: now }, billingStatus: { not: 'PAID' } },
          ],
        },
      }),
      this.prisma.user.count({ where: { createdAt: { gte: startOfMonth } } }),
      this.prisma.user.count({ where: { accountType: 'ANUNCIANTE' } }),
      this.prisma.user.count({ where: { accountType: 'SOLICITANTE' } }),
      this.prisma.post.count({ where: { status: 'ACTIVE' } }),
      this.prisma.postReport.count({ where: { status: 'OPEN' } }),
      this.prisma.userReport.count({ where: { status: 'OPEN' } }),
    ]);

    return {
      totalUsers,
      activeUsers,
      suspendedUsers,
      paidUsers,
      dueRenewals,
      overdueRenewals,
      newThisMonth,
      advertisers,
      requesters,
      activePosts,
      openReports: openPostReports + openUserReports,
    };
  }

  async findById(id: string) {
    return this.prisma.user.findUnique({
      where: {
        id,
      },
      select: publicUserSelect,
    });
  }

  async findPrivateById(id: string) {
    return this.prisma.user.findUnique({
      where: {
        id,
      },
    });
  }

  async updatePassword(id: string, password: string) {
    return this.prisma.user.update({
      where: {
        id,
      },
      data: {
        password,
      },
      select: publicUserSelect,
    });
  }

  async createPasswordResetToken(
    userId: string,
    tokenHash: string,
    expiresAt: Date,
  ) {
    return this.prisma.passwordResetToken.create({
      data: {
        userId,
        tokenHash,
        expiresAt,
      },
    });
  }

  async findPasswordResetToken(tokenHash: string) {
    return this.prisma.passwordResetToken.findUnique({
      where: {
        tokenHash,
      },
      include: {
        user: true,
      },
    });
  }

  async markPasswordResetTokenUsed(id: string) {
    return this.prisma.passwordResetToken.update({
      where: {
        id,
      },
      data: {
        usedAt: new Date(),
      },
    });
  }

  async createEmailVerificationToken(
    userId: string,
    tokenHash: string,
    expiresAt: Date,
  ) {
    return this.prisma.emailVerificationToken.create({
      data: {
        userId,
        tokenHash,
        expiresAt,
      },
    });
  }

  async findEmailVerificationToken(tokenHash: string) {
    return this.prisma.emailVerificationToken.findUnique({
      where: {
        tokenHash,
      },
      include: {
        user: true,
      },
    });
  }

  async markEmailVerificationTokenUsed(id: string) {
    return this.prisma.emailVerificationToken.update({
      where: {
        id,
      },
      data: {
        usedAt: new Date(),
      },
    });
  }

  async markEmailVerified(id: string) {
    return this.prisma.user.update({
      where: {
        id,
      },
      data: {
        emailVerified: true,
      },
      select: publicUserSelect,
    });
  }

  async updateStatus(id: string, data: UpdateUserStatusDto) {
    return this.prisma.user.update({
      where: {
        id,
      },
      data: {
        status: data.status,
      },
      select: publicUserSelect,
    });
  }

  async updateBilling(id: string, data: UpdateUserBillingDto) {
    return this.prisma.user.update({
      where: {
        id,
      },
      data: {
        billingStatus: data.billingStatus,
        renewalDueAt: data.renewalDueAt ? new Date(data.renewalDueAt) : null,
      },
      select: publicUserSelect,
    });
  }

  async updateProfile(
    id: string,
    data: {
      accountType?: string;
      firstName?: string;
      lastName?: string;
      phone?: string;
      city?: string;
      state?: string;
      neighborhood?: string;
      profession?: string;
      description?: string;
      profilePhoto?: string;
      whatsapp?: string;
      instagramUrl?: string;
      facebookUrl?: string;
      tiktokUrl?: string;
      xUrl?: string;
      websiteUrl?: string;
    },
  ) {
    return this.prisma.user.update({
      where: {
        id,
      },
      data,
      select: publicUserSelect,
    });
  }
}
