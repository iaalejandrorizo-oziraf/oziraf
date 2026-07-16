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
  }) {
    return this.prisma.user.create({
      data,
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
    });
  }
  async updateProfile(id: string, data: {
  firstName?: string;
  lastName?: string;
  phone?: string;
  city?: string;
  state?: string;
  neighborhood?: string;
  profession?: string;
  description?: string;
}) {
  return this.prisma.user.update({
    where: {
      id,
    },
    data,
  });
}
}