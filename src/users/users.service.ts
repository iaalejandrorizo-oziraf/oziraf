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
  createdAt: true,
  updatedAt: true,
  emailVerified: true,
  profilePhoto: true,
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
    phone?: string;
    city?: string;
    state?: string;
    neighborhood?: string;
    profession?: string;
    description?: string;
    profilePhoto?: string;
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
      firstName?: string;
      lastName?: string;
      phone?: string;
      city?: string;
      state?: string;
      neighborhood?: string;
      profession?: string;
      description?: string;
      profilePhoto?: string;
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
