import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  buildPaginatedResponse,
  getPagination,
} from '../common/utils/pagination.util';
import { PrismaService } from '../prisma/prisma.service';
import { ListUsersQueryDto } from './dto/list-users-query.dto';
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
