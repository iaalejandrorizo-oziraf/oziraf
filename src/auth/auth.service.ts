import {
  Injectable,
  ConflictException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../users/users.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { ConfirmEmailVerificationDto } from './dto/confirm-email-verification.dto';
import { ConfirmPasswordResetDto } from './dto/confirm-password-reset.dto';
import { RequestPasswordResetDto } from './dto/request-password-reset.dto';
import * as bcrypt from 'bcrypt';
import { createHash, randomBytes } from 'crypto';

const PASSWORD_RESET_MESSAGE =
  'Si el correo existe, recibirás instrucciones para recuperar tu contraseña';
const EMAIL_VERIFICATION_MESSAGE =
  'Si tu cuenta está activa, recibirás instrucciones para verificar tu correo';

function hashToken(token: string) {
  return createHash('sha256').update(token).digest('hex');
}

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
  ) {}

  async register(registerDto: RegisterDto) {
    const existingUser = await this.usersService.findByEmail(registerDto.email);

    if (existingUser) {
      throw new ConflictException('El correo ya está registrado');
    }

    const hashedPassword = await bcrypt.hash(registerDto.password, 10);

    return this.usersService.create({
      email: registerDto.email,
      password: hashedPassword,
      firstName: registerDto.firstName,
      lastName: registerDto.lastName,
      accountType: registerDto.accountType,
      phone: registerDto.phone,
      city: registerDto.city,
      state: registerDto.state,
      neighborhood: registerDto.neighborhood,
      profession: registerDto.profession,
      description: registerDto.description,
      profilePhoto: registerDto.profilePhoto,
      whatsapp: registerDto.whatsapp,
      instagramUrl: registerDto.instagramUrl,
      facebookUrl: registerDto.facebookUrl,
      websiteUrl: registerDto.websiteUrl,
    });
  }

  async login(loginDto: LoginDto) {
    const user = await this.usersService.findByEmail(loginDto.email);

    if (!user) {
      throw new UnauthorizedException('Correo o contraseña incorrectos');
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedException('La cuenta no está activa');
    }

    const passwordValid = await bcrypt.compare(
      loginDto.password,
      user.password,
    );

    if (!passwordValid) {
      throw new UnauthorizedException('Correo o contraseña incorrectos');
    }

    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
    };

    return {
      access_token: await this.jwtService.signAsync(payload),
    };
  }

  async changePassword(userId: string, changePasswordDto: ChangePasswordDto) {
    const user = await this.usersService.findPrivateById(userId);

    if (!user) {
      throw new UnauthorizedException('Usuario no autenticado');
    }

    const currentPasswordValid = await bcrypt.compare(
      changePasswordDto.currentPassword,
      user.password,
    );

    if (!currentPasswordValid) {
      throw new UnauthorizedException('La contraseña actual es incorrecta');
    }

    const hashedPassword = await bcrypt.hash(changePasswordDto.newPassword, 10);

    return this.usersService.updatePassword(userId, hashedPassword);
  }

  async requestPasswordReset(requestPasswordResetDto: RequestPasswordResetDto) {
    const user = await this.usersService.findByEmail(
      requestPasswordResetDto.email,
    );

    if (!user || user.status !== 'ACTIVE') {
      return {
        message: PASSWORD_RESET_MESSAGE,
      };
    }

    const resetToken = randomBytes(32).toString('hex');
    const tokenHash = hashToken(resetToken);
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);

    await this.usersService.createPasswordResetToken(
      user.id,
      tokenHash,
      expiresAt,
    );

    // The raw token must be delivered out-of-band (for example by email),
    // never returned to the requesting client.
    return {
      message: PASSWORD_RESET_MESSAGE,
    };
  }

  async confirmPasswordReset(confirmPasswordResetDto: ConfirmPasswordResetDto) {
    const tokenHash = hashToken(confirmPasswordResetDto.token);
    const resetToken =
      await this.usersService.findPasswordResetToken(tokenHash);

    if (
      !resetToken ||
      resetToken.usedAt ||
      resetToken.expiresAt.getTime() < Date.now() ||
      resetToken.user.status !== 'ACTIVE'
    ) {
      throw new UnauthorizedException('El token de recuperación no es válido');
    }

    const hashedPassword = await bcrypt.hash(
      confirmPasswordResetDto.newPassword,
      10,
    );

    const user = await this.usersService.updatePassword(
      resetToken.userId,
      hashedPassword,
    );

    await this.usersService.markPasswordResetTokenUsed(resetToken.id);

    return user;
  }

  async requestEmailVerification(userId: string) {
    const user = await this.usersService.findPrivateById(userId);

    if (!user || user.status !== 'ACTIVE' || user.emailVerified) {
      return {
        message: EMAIL_VERIFICATION_MESSAGE,
      };
    }

    const verificationToken = randomBytes(32).toString('hex');
    const tokenHash = hashToken(verificationToken);
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await this.usersService.createEmailVerificationToken(
      user.id,
      tokenHash,
      expiresAt,
    );

    // The verification token must be delivered out-of-band.
    return {
      message: EMAIL_VERIFICATION_MESSAGE,
    };
  }

  async confirmEmailVerification(
    confirmEmailVerificationDto: ConfirmEmailVerificationDto,
  ) {
    const tokenHash = createHash('sha256')
      .update(confirmEmailVerificationDto.token)
      .digest('hex');
    const verificationToken =
      await this.usersService.findEmailVerificationToken(tokenHash);

    if (
      !verificationToken ||
      verificationToken.usedAt ||
      verificationToken.expiresAt.getTime() < Date.now() ||
      verificationToken.user.status !== 'ACTIVE'
    ) {
      throw new UnauthorizedException('El token de verificación no es válido');
    }

    const user = await this.usersService.markEmailVerified(
      verificationToken.userId,
    );

    await this.usersService.markEmailVerificationTokenUsed(
      verificationToken.id,
    );

    return user;
  }
}
