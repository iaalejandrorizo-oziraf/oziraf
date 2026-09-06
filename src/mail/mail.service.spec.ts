import { ConfigService } from '@nestjs/config';
import { MailService } from './mail.service';

describe('MailService', () => {
  const fetchMock = jest.fn();
  let originalFetch: typeof global.fetch;

  beforeEach(() => {
    originalFetch = global.fetch;
    global.fetch = fetchMock;
    fetchMock.mockReset();
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('sends password reset emails through Resend when configured', async () => {
    const service = new MailService({
      get: jest.fn((key: string) => {
        const values: Record<string, string> = {
          RESEND_API_KEY: 'resend-key',
          MAIL_FROM: 'OZIRAF <no-reply@example.com>',
          PUBLIC_WEB_URL: 'https://oziraf.com',
        };
        return values[key];
      }),
    } as unknown as ConfigService);
    fetchMock.mockResolvedValue({ ok: true });

    await service.sendPasswordReset('user@example.com', 'reset-token');

    expect(fetchMock).toHaveBeenCalledWith(
      'https://api.resend.com/emails',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Authorization: 'Bearer resend-key',
        }),
        body: expect.stringContaining(
          'https://oziraf.com/reset-password?token=reset-token',
        ),
      }),
    );
  });

  it('does not call email provider when API key is missing', async () => {
    const service = new MailService({
      get: jest.fn(),
    } as unknown as ConfigService);

    await service.sendEmailVerification('user@example.com', 'verify-token');

    expect(fetchMock).not.toHaveBeenCalled();
  });
});
