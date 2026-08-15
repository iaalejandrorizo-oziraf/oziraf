import { Test, TestingModule } from '@nestjs/testing';
import { ContactsController } from './contacts.controller';
import { ContactsService } from './contacts.service';

describe('ContactsController', () => {
  let controller: ContactsController;
  let contactsService: {
    create: jest.Mock;
    findReceived: jest.Mock;
    updateStatus: jest.Mock;
  };

  beforeEach(async () => {
    contactsService = {
      create: jest.fn(),
      findReceived: jest.fn(),
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
    const leads = [
      {
        id: 'lead-id',
        ownerId: 'owner-id',
      },
    ];
    contactsService.findReceived.mockResolvedValue(leads);

    const result = await controller.findReceived({
      user: {
        userId: 'owner-id',
      },
    });

    expect(contactsService.findReceived).toHaveBeenCalledWith('owner-id');
    expect(result).toBe(leads);
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
