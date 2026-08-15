import { Test, TestingModule } from '@nestjs/testing';
import { ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';

describe('ReportsController', () => {
  let controller: ReportsController;
  let reportsService: {
    findAll: jest.Mock;
    findMine: jest.Mock;
    reportPost: jest.Mock;
    updateStatus: jest.Mock;
  };

  beforeEach(async () => {
    reportsService = {
      findAll: jest.fn(),
      findMine: jest.fn(),
      reportPost: jest.fn(),
      updateStatus: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ReportsController],
      providers: [
        {
          provide: ReportsService,
          useValue: reportsService,
        },
      ],
    }).compile();

    controller = module.get<ReportsController>(ReportsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('creates a post report for the authenticated user', async () => {
    const report = {
      id: 'report-id',
      postId: 'post-id',
      reporterId: 'reporter-id',
    };
    reportsService.reportPost.mockResolvedValue(report);

    const result = await controller.reportPost(
      'post-id',
      {
        user: {
          userId: 'reporter-id',
        },
      },
      {
        reason: 'SPAM',
      },
    );

    expect(reportsService.reportPost).toHaveBeenCalledWith(
      'post-id',
      'reporter-id',
      {
        reason: 'SPAM',
      },
    );
    expect(result).toBe(report);
  });

  it('returns reports created by the authenticated user', async () => {
    const reports = [
      {
        id: 'report-id',
        reporterId: 'reporter-id',
      },
    ];
    reportsService.findMine.mockResolvedValue(reports);

    const result = await controller.findMine({
      user: {
        userId: 'reporter-id',
      },
    });

    expect(reportsService.findMine).toHaveBeenCalledWith('reporter-id');
    expect(result).toBe(reports);
  });

  it('returns paginated reports for admins', async () => {
    const response = {
      data: [],
      page: 1,
      limit: 10,
      total: 0,
      totalPages: 0,
    };
    reportsService.findAll.mockResolvedValue(response);

    const result = await controller.findAll({
      page: 1,
      limit: 10,
      status: 'OPEN',
    });

    expect(reportsService.findAll).toHaveBeenCalledWith({
      page: 1,
      limit: 10,
      status: 'OPEN',
    });
    expect(result).toBe(response);
  });

  it('updates report status for admins', async () => {
    const report = {
      id: 'report-id',
      status: 'RESOLVED',
    };
    reportsService.updateStatus.mockResolvedValue(report);

    const result = await controller.updateStatus('report-id', {
      status: 'RESOLVED',
    });

    expect(reportsService.updateStatus).toHaveBeenCalledWith('report-id', {
      status: 'RESOLVED',
    });
    expect(result).toBe(report);
  });
});
