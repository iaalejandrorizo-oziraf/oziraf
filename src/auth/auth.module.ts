import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { UsersModule } from '../users/users.module';
import { JwtStrategy } from './strategies/jwt.strategy';
import { PassportModule } from '@nestjs/passport';

@Module({
 imports: [
  UsersModule,

  PassportModule.register({
    defaultStrategy: 'jwt',
  }),

  JwtModule.register({
    secret: 'oziraf-super-secret-key',
    signOptions: {
      expiresIn: '7d',
    },
  }),
],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
  ],
})
export class AuthModule {}