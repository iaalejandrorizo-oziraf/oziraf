import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

type MailMessage = {
  to: string;
  subject: string;
  text: string;
  html: string;
};

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(private readonly configService: ConfigService) {}

  async sendPasswordReset(email: string, token: string) {
    const link = this.buildWebLink('/reset-password', { token });
    await this.send({
      to: email,
      subject: 'Recupera tu contraseña de OZIRAF',
      text: `Abre este enlace para crear una nueva contraseña: ${link}`,
      html: `<p>Abre este enlace para crear una nueva contraseña:</p><p><a href="${link}">${link}</a></p>`,
    });
  }

  async sendEmailVerification(email: string, token: string) {
    const link = this.buildWebLink('/verify-email', { token });
    await this.send({
      to: email,
      subject: 'Verifica tu correo de OZIRAF',
      text: `Abre este enlace para verificar tu correo: ${link}`,
      html: `<p>Abre este enlace para verificar tu correo:</p><p><a href="${link}">${link}</a></p>`,
    });
  }

  private buildWebLink(path: string, params: Record<string, string>) {
    const publicWebUrl =
      this.configService.get<string>('PUBLIC_WEB_URL')?.trim() ||
      'http://localhost:8092';
    const url = new URL(
      path,
      publicWebUrl.endsWith('/') ? publicWebUrl : `${publicWebUrl}/`,
    );
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }
    return url.toString();
  }

  private async send(message: MailMessage) {
    const apiKey = this.configService.get<string>('RESEND_API_KEY')?.trim();
    if (!apiKey) {
      this.logger.warn(
        `Email provider not configured. ${message.subject}: ${message.text}`,
      );
      return;
    }

    const from =
      this.configService.get<string>('MAIL_FROM')?.trim() ||
      'OZIRAF <no-reply@oziraf.com>';
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [message.to],
        subject: message.subject,
        text: message.text,
        html: message.html,
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      this.logger.error(
        `Email delivery failed with ${response.status}: ${body}`,
      );
    }
  }
}
