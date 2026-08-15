import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreatePostReportDto } from './dto/create-post-report.dto';
import { ReportsService } from './reports.service';

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
}
