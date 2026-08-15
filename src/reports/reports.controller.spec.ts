import { Test, TestingModule } from '@nestjs/testing';
import { ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';

describe('ReportsController', () => {
  let controller: ReportsController;
  let reportsService: {
    findMine: jest.Mock;
    reportPost: jest.Mock;
  };

  beforeEach(async () => {
    reportsService = {
      findMine: jest.fn(),
      reportPost: jest.fn(),
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
});
