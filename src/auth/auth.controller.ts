import {
  Body,
  Controller,
  Get,
  Patch,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { ConfirmEmailVerificationDto } from './dto/confirm-email-verification.dto';
import { ConfirmPasswordResetDto } from './dto/confirm-password-reset.dto';
import { RequestPasswordResetDto } from './dto/request-password-reset.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('register')
  @Throttle({ default: { ttl: 60_000, limit: 5 } })
  register(@Body() registerDto: RegisterDto) {
    return this.authService.register(registerDto);
  }

  @Post('login')
  @Throttle({ default: { ttl: 60_000, limit: 10 } })
  login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Post('password-reset/request')
  @Throttle({ default: { ttl: 60_000, limit: 3 } })
  requestPasswordReset(
    @Body() requestPasswordResetDto: RequestPasswordResetDto,
  ) {
    return this.authService.requestPasswordReset(requestPasswordResetDto);
  }

  @Post('password-reset/confirm')
  @Throttle({ default: { ttl: 60_000, limit: 5 } })
  confirmPasswordReset(
    @Body() confirmPasswordResetDto: ConfirmPasswordResetDto,
  ) {
    return this.authService.confirmPasswordReset(confirmPasswordResetDto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('email-verification/request')
  @Throttle({ default: { ttl: 60_000, limit: 3 } })
  requestEmailVerification(@Request() req) {
    return this.authService.requestEmailVerification(req.user.userId);
  }

  @Post('email-verification/confirm')
  @Throttle({ default: { ttl: 60_000, limit: 5 } })
  confirmEmailVerification(
    @Body() confirmEmailVerificationDto: ConfirmEmailVerificationDto,
  ) {
    return this.authService.confirmEmailVerification(
      confirmEmailVerificationDto,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Patch('password')
  changePassword(
    @Request() req,
    @Body() changePasswordDto: ChangePasswordDto,
  ) {
    return this.authService.changePassword(req.user.userId, changePasswordDto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  getProfile(@Request() req) {
    return req.user;
  }
}
