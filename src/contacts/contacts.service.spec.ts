import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { ContactsService } from './contacts.service';

describe('ContactsService', () => {
  let service: ContactsService;
  let prisma: {
    contactLead: {
      count: jest.Mock;
      create: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
    };
    post: {
      findUnique: jest.Mock;
    };
  };

  beforeEach(async () => {
    prisma = {
      contactLead: {
        count: jest.fn(),
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      post: {
        findUnique: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ContactsService,
        {
          provide: PrismaService,
          useValue: prisma,
        },
      ],
    }).compile();

    service = module.get<ContactsService>(ContactsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('creates a contact lead for an active post owned by another user', async () => {
    const lead = {
      id: 'lead-id',
      postId: 'post-id',
      senderId: 'sender-id',
      ownerId: 'owner-id',
      message: 'Me interesa tu servicio de arquitectura.',
    };
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      userId: 'owner-id',
      status: 'ACTIVE',
    });
    prisma.contactLead.create.mockResolvedValue(lead);

    const result = await service.create('post-id', 'sender-id', {
      message: 'Me interesa tu servicio de arquitectura.',
    });

    expect(prisma.contactLead.create).toHaveBeenCalledWith({
      data: {
        postId: 'post-id',
        senderId: 'sender-id',
        ownerId: 'owner-id',
        message: 'Me interesa tu servicio de arquitectura.',
      },
      include: expect.any(Object),
    });
    expect(result).toBe(lead);
  });

  it('rejects leads for missing or inactive posts', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      userId: 'owner-id',
      status: 'DELETED',
    });

    await expect(
      service.create('post-id', 'sender-id', {
        message: 'Me interesa tu servicio de arquitectura.',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('rejects leads for the sender own post', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      userId: 'sender-id',
      status: 'ACTIVE',
    });

    await expect(
      service.create('post-id', 'sender-id', {
        message: 'Me interesa tu servicio de arquitectura.',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('finds received leads for an owner', async () => {
    const leads = [
      {
        id: 'lead-id',
        ownerId: 'owner-id',
      },
    ];
    prisma.contactLead.findMany.mockResolvedValue(leads);
    prisma.contactLead.count.mockResolvedValue(1);

    const result = await service.findReceived('owner-id', {
      page: 2,
      limit: 10,
      status: 'NEW',
    });

    expect(prisma.contactLead.findMany).toHaveBeenCalledWith({
      where: {
        ownerId: 'owner-id',
        status: 'NEW',
      },
      include: expect.any(Object),
      skip: 10,
      take: 10,
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(prisma.contactLead.count).toHaveBeenCalledWith({
      where: {
        ownerId: 'owner-id',
        status: 'NEW',
      },
    });
    expect(result).toEqual({
      data: leads,
      page: 2,
      limit: 10,
      total: 1,
      totalPages: 1,
    });
  });

  it('updates a received lead status for the owner', async () => {
    const lead = {
      id: 'lead-id',
      ownerId: 'owner-id',
      status: 'NEW',
    };
    const updatedLead = {
      ...lead,
      status: 'READ',
    };
    prisma.contactLead.findUnique.mockResolvedValue(lead);
    prisma.contactLead.update.mockResolvedValue(updatedLead);

    const result = await service.updateStatus('lead-id', 'owner-id', {
      status: 'READ',
    });

    expect(prisma.contactLead.update).toHaveBeenCalledWith({
      where: {
        id: 'lead-id',
      },
      data: {
        status: 'READ',
      },
      include: expect.any(Object),
    });
    expect(result).toBe(updatedLead);
  });

  it('rejects updating a missing lead status', async () => {
    prisma.contactLead.findUnique.mockResolvedValue(null);

    await expect(
      service.updateStatus('lead-id', 'owner-id', {
        status: 'READ',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('rejects updating another owner lead status', async () => {
    prisma.contactLead.findUnique.mockResolvedValue({
      id: 'lead-id',
      ownerId: 'owner-id',
    });

    await expect(
      service.updateStatus('lead-id', 'other-owner-id', {
        status: 'READ',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
