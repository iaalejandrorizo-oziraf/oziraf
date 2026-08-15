import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';

import { PostsService } from './posts.service';
import { AdminGuard } from '../auth/guards/admin.guard';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminListPostsQueryDto } from './dto/admin-list-posts-query.dto';
import { AdminUpdatePostStatusDto } from './dto/admin-update-post-status.dto';
import { CreatePostDto } from './dto/create-post.dto';
import { ListPostsQueryDto } from './dto/list-posts-query.dto';
import { MyPostsQueryDto } from './dto/my-posts-query.dto';
import { SearchPostsQueryDto } from './dto/search-posts-query.dto';
import { UpdatePostStatusDto } from './dto/update-post-status.dto';
import { UpdatePostDto } from './dto/update-post.dto';

@Controller('posts')
export class PostsController {
  constructor(private postsService: PostsService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  async create(@Request() req, @Body() createPostDto: CreatePostDto) {
    return this.postsService.create(req.user.userId, createPostDto);
  }

  @Get()
  async findAll(@Query() query: ListPostsQueryDto) {
    return this.postsService.findAll(query);
  }

  @Get('search')
  async search(@Query() query: SearchPostsQueryDto) {
    return this.postsService.search(query);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/stats')
  async findMyStats(@Request() req) {
    return this.postsService.findMyStats(req.user.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async findMine(@Request() req, @Query() query: MyPostsQueryDto) {
    return this.postsService.findMine(req.user.userId, query);
  }

  @Get('filters')
  async findFilters() {
    return this.postsService.findFilters();
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('admin')
  async findAllForAdmin(@Query() query: AdminListPostsQueryDto) {
    return this.postsService.findAllForAdmin(query);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Patch('admin/:id/status')
  async updateStatusForAdmin(
    @Param('id') id: string,
    @Body() adminUpdatePostStatusDto: AdminUpdatePostStatusDto,
  ) {
    return this.postsService.updateStatusForAdmin(
      id,
      adminUpdatePostStatusDto,
    );
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.postsService.findOne(id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id/status')
  async updateStatus(
    @Param('id') id: string,
    @Request() req,
    @Body() updatePostStatusDto: UpdatePostStatusDto,
  ) {
    return this.postsService.updateStatus(
      id,
      req.user.userId,
      updatePostStatusDto,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Request() req,
    @Body() updatePostDto: UpdatePostDto,
  ) {
    return this.postsService.update(id, req.user.userId, updatePostDto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  async remove(@Param('id') id: string, @Request() req) {
    return this.postsService.remove(id, req.user.userId);
  }
}
