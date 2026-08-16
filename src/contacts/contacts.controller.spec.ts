import { Test, TestingModule } from '@nestjs/testing';
import { ContactsController } from './contacts.controller';
import { ContactsService } from './contacts.service';

describe('ContactsController', () => {
  let controller: ContactsController;
  let contactsService: {
    create: jest.Mock;
    findReceived: jest.Mock;
    findSent: jest.Mock;
    updateStatus: jest.Mock;
  };

  beforeEach(async () => {
    contactsService = {
      create: jest.fn(),
      findReceived: jest.fn(),
      findSent: jest.fn(),
      updateStatus: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ContactsController],
      providers: [
        {
          provide: ContactsService,
          useValue: contactsService,
        },
      ],
    }).compile();

    controller = module.get<ContactsController>(ContactsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('creates a contact lead for the authenticated user', async () => {
    const lead = {
      id: 'lead-id',
      postId: 'post-id',
      senderId: 'sender-id',
    };
    contactsService.create.mockResolvedValue(lead);

    const result = await controller.create(
      'post-id',
      {
        user: {
          userId: 'sender-id',
        },
      },
      {
        message: 'Me interesa tu servicio de arquitectura.',
      },
    );

    expect(contactsService.create).toHaveBeenCalledWith('post-id', 'sender-id', {
      message: 'Me interesa tu servicio de arquitectura.',
    });
    expect(result).toBe(lead);
  });

  it('returns received leads for the authenticated user', async () => {
    const response = {
      data: [
        {
          id: 'lead-id',
          ownerId: 'owner-id',
        },
      ],
      page: 1,
      limit: 10,
      total: 1,
      totalPages: 1,
    };
    contactsService.findReceived.mockResolvedValue(response);

    const result = await controller.findReceived(
      {
        user: {
          userId: 'owner-id',
        },
      },
      {
        page: 1,
        limit: 10,
        status: 'NEW',
      },
    );

    expect(contactsService.findReceived).toHaveBeenCalledWith('owner-id', {
      page: 1,
      limit: 10,
      status: 'NEW',
    });
    expect(result).toBe(response);
  });

  it('returns sent leads for the authenticated user', async () => {
    const response = {
      data: [
        {
          id: 'lead-id',
          senderId: 'sender-id',
        },
      ],
      page: 1,
      limit: 10,
      total: 1,
      totalPages: 1,
    };
    contactsService.findSent.mockResolvedValue(response);

    const result = await controller.findSent(
      {
        user: {
          userId: 'sender-id',
        },
      },
      {
        page: 1,
        limit: 10,
        status: 'NEW',
      },
    );

    expect(contactsService.findSent).toHaveBeenCalledWith('sender-id', {
      page: 1,
      limit: 10,
      status: 'NEW',
    });
    expect(result).toBe(response);
  });

  it('updates a received lead status for the authenticated user', async () => {
    const lead = {
      id: 'lead-id',
      ownerId: 'owner-id',
      status: 'READ',
    };
    contactsService.updateStatus.mockResolvedValue(lead);

    const result = await controller.updateStatus(
      'lead-id',
      {
        user: {
          userId: 'owner-id',
        },
      },
      {
        status: 'READ',
      },
    );

    expect(contactsService.updateStatus).toHaveBeenCalledWith(
      'lead-id',
      'owner-id',
      {
        status: 'READ',
      },
    );
    expect(result).toBe(lead);
  });
});
