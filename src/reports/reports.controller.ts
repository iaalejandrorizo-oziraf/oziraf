import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { AdminGuard } from '../auth/guards/admin.guard';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreatePostReportDto } from './dto/create-post-report.dto';
import { ListReportsQueryDto } from './dto/list-reports-query.dto';
import { UpdateReportStatusDto } from './dto/update-report-status.dto';
import { ReportsService } from './reports.service';
import { CreateUserReportDto } from './dto/create-user-report.dto';

@UseGuards(JwtAuthGuard)
@Controller('reports')
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Post('posts/:postId')
  async reportPost(
    @Param('postId') postId: string,
    @Request() req,
    @Body() createPostReportDto: CreatePostReportDto,
  ) {
    return this.reportsService.reportPost(
      postId,
      req.user.userId,
      createPostReportDto,
    );
  }

  @Get('me')
  async findMine(@Request() req) {
    return this.reportsService.findMine(req.user.userId);
  }

  @Post('users/:userId')
  async reportUser(
    @Param('userId') userId: string,
    @Request() req,
    @Body() createUserReportDto: CreateUserReportDto,
  ) {
    return this.reportsService.reportUser(
      userId,
      req.user.userId,
      createUserReportDto,
    );
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('admin')
  async findAll(@Query() query: ListReportsQueryDto) {
    return this.reportsService.findAll(query);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Patch('admin/:id/status')
  async updateStatus(
    @Param('id') id: string,
    @Body() updateReportStatusDto: UpdateReportStatusDto,
  ) {
    return this.reportsService.updateStatus(id, updateReportStatusDto);
  }
}
