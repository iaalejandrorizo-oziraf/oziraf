import {
  Controller,
  Get,
  Patch,
  Body,
  Request,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';

import { UsersService } from './users.service';
import { AdminGuard } from '../auth/guards/admin.guard';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ListUsersQueryDto } from './dto/list-users-query.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UpdateUserBillingDto } from './dto/update-user-billing.dto';
import { UpdateUserStatusDto } from './dto/update-user-status.dto';

@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('admin')
  async findAllForAdmin(@Query() query: ListUsersQueryDto) {
    return this.usersService.findAllForAdmin(query);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('admin/summary')
  async getAdminSummary() {
    return this.usersService.getAdminSummary();
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Patch('admin/:id/status')
  async updateStatus(
    @Param('id') id: string,
    @Body() updateUserStatusDto: UpdateUserStatusDto,
  ) {
    return this.usersService.updateStatus(id, updateUserStatusDto);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Patch('admin/:id/billing')
  async updateBilling(
    @Param('id') id: string,
    @Body() updateUserBillingDto: UpdateUserBillingDto,
  ) {
    return this.usersService.updateBilling(id, updateUserBillingDto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('profile')
  async getProfile(@Request() req) {
    return this.usersService.findById(req.user.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('profile')
  async updateProfile(
    @Request() req,
    @Body() updateProfileDto: UpdateProfileDto,
  ) {
    return this.usersService.updateProfile(req.user.userId, updateProfileDto);
  }
}
