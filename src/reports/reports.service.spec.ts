import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { ReportsService } from './reports.service';

describe('ReportsService', () => {
  let service: ReportsService;
  let prisma: {
    post: {
      findUnique: jest.Mock;
    };
    user: {
      findUnique: jest.Mock;
    };
    postReport: {
      count: jest.Mock;
      create: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
    };
    userReport: {
      count: jest.Mock;
      create: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
    };
  };

  beforeEach(async () => {
    prisma = {
      post: {
        findUnique: jest.fn(),
      },
      user: {
        findUnique: jest.fn(),
      },
      postReport: {
        count: jest.fn(),
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      userReport: {
        count: jest.fn(),
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ReportsService,
        {
          provide: PrismaService,
          useValue: prisma,
        },
      ],
    }).compile();

    service = module.get<ReportsService>(ReportsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('creates a report for an active post owned by another user', async () => {
    const report = {
      id: 'report-id',
      postId: 'post-id',
      reporterId: 'reporter-id',
    };
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      userId: 'owner-id',
      status: 'ACTIVE',
    });
    prisma.postReport.findUnique.mockResolvedValue(null);
    prisma.postReport.create.mockResolvedValue(report);

    const result = await service.reportPost('post-id', 'reporter-id', {
      reason: 'FRAUD',
      details: 'Parece falso.',
    });

    expect(prisma.postReport.create).toHaveBeenCalledWith({
      data: {
        postId: 'post-id',
        reporterId: 'reporter-id',
        reason: 'FRAUD',
        details: 'Parece falso.',
      },
      include: {
        post: true,
      },
    });
    expect(result).toBe(report);
  });

  it('rejects reports for missing or inactive posts', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      status: 'DELETED',
    });

    await expect(
      service.reportPost('post-id', 'reporter-id', {
        reason: 'SPAM',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('rejects reports for the reporter own post', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      userId: 'reporter-id',
      status: 'ACTIVE',
    });

    await expect(
      service.reportPost('post-id', 'reporter-id', {
        reason: 'SPAM',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects duplicate reports', async () => {
    prisma.post.findUnique.mockResolvedValue({
      id: 'post-id',
      userId: 'owner-id',
      status: 'ACTIVE',
    });
    prisma.postReport.findUnique.mockResolvedValue({
      id: 'report-id',
    });

    await expect(
      service.reportPost('post-id', 'reporter-id', {
        reason: 'SPAM',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('finds reports created by a user', async () => {
    const createdAt = new Date('2026-09-03T00:00:00.000Z');
    const reports = [
      {
        id: 'report-id',
        reporterId: 'reporter-id',
        createdAt,
      },
    ];
    prisma.postReport.findMany.mockResolvedValue(reports);
    prisma.userReport.findMany.mockResolvedValue([]);

    const result = await service.findMine('reporter-id');

    expect(prisma.postReport.findMany).toHaveBeenCalledWith({
      where: {
        reporterId: 'reporter-id',
      },
      include: {
        post: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(prisma.userReport.findMany).toHaveBeenCalledWith({
      where: {
        reporterId: 'reporter-id',
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
    });
    expect(result).toEqual([{ ...reports[0], type: 'POST' }]);
  });

  it('finds all reports with pagination for admins', async () => {
    const createdAt = new Date('2026-09-03T00:00:00.000Z');
    const reports = [
      {
        id: 'report-id',
        status: 'OPEN',
        createdAt,
      },
    ];
    prisma.postReport.findMany.mockResolvedValue(reports);
    prisma.userReport.findMany.mockResolvedValue([]);
    prisma.postReport.count.mockResolvedValue(1);
    prisma.userReport.count.mockResolvedValue(0);

    const result = await service.findAll({
      page: 1,
      limit: 10,
      status: 'OPEN',
    });

    expect(prisma.postReport.findMany).toHaveBeenCalledWith({
      where: {
        status: 'OPEN',
      },
      include: expect.any(Object),
      skip: 0,
      take: 10,
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(prisma.userReport.findMany).toHaveBeenCalledWith({
      where: {
        status: 'OPEN',
      },
      include: expect.any(Object),
      skip: 0,
      take: 10,
      orderBy: {
        createdAt: 'desc',
      },
    });
    expect(result).toEqual({
      data: [{ ...reports[0], type: 'POST' }],
      page: 1,
      limit: 10,
      total: 1,
      totalPages: 1,
    });
  });

  it('updates report status', async () => {
    const report = {
      id: 'report-id',
      status: 'OPEN',
    };
    const updatedReport = {
      ...report,
      status: 'RESOLVED',
    };
    prisma.postReport.findUnique.mockResolvedValue(report);
    prisma.postReport.update.mockResolvedValue(updatedReport);

    const result = await service.updateStatus('report-id', {
      status: 'RESOLVED',
    });

    expect(prisma.postReport.update).toHaveBeenCalledWith({
      where: {
        id: 'report-id',
      },
      data: {
        status: 'RESOLVED',
      },
      include: expect.any(Object),
    });
    expect(result).toEqual({ ...updatedReport, type: 'POST' });
  });

  it('rejects updating missing reports', async () => {
    prisma.postReport.findUnique.mockResolvedValue(null);
    prisma.userReport.findUnique.mockResolvedValue(null);

    await expect(
      service.updateStatus('report-id', {
        status: 'RESOLVED',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
