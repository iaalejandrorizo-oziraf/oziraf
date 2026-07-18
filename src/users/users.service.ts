import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

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
      select: {
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
      },
    });
  }

  async findByEmail(email: string) {
    return this.prisma.user.findUnique({
      where: {
        email,
      },
    });
  }

  async findById(id: string) {
    return this.prisma.user.findUnique({
      where: {
        id,
      },
      select: {
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
      },
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
      select: {
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
      },
    });
  }
}
