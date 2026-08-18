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
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';

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

type UploadedMediaFile = {
  buffer: Buffer;
  mimetype: string;
  originalname: string;
  size: number;
};

function inferMediaMimeType(file?: UploadedMediaFile) {
  if (!file || (file.mimetype && file.mimetype !== 'application/octet-stream')) {
    return file;
  }

  const name = file.originalname.toLowerCase();
  const inferred = name.endsWith('.jpg') || name.endsWith('.jpeg')
    ? 'image/jpeg'
    : name.endsWith('.png')
      ? 'image/png'
      : name.endsWith('.webp')
        ? 'image/webp'
        : name.endsWith('.mp4')
          ? 'video/mp4'
          : name.endsWith('.mov')
            ? 'video/quicktime'
            : name.endsWith('.webm')
              ? 'video/webm'
              : name.endsWith('.3gp')
                ? 'video/3gpp'
                : file.mimetype;

  return {
    ...file,
    mimetype: inferred,
  };
}

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

  @UseGuards(JwtAuthGuard)
  @Post(':id/media')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 12 * 1024 * 1024,
      },
    }),
  )
  async uploadMedia(
    @Param('id') id: string,
    @Request() req,
    @UploadedFile() file?: UploadedMediaFile,
  ) {
    return this.postsService.addMedia(
      id,
      req.user.userId,
      inferMediaMimeType(file),
    );
  }

  @Get('media/:mediaId')
  async getMedia(@Param('mediaId') mediaId: string, @Res() res: Response) {
    const media = await this.postsService.findMedia(mediaId);
    res.setHeader('Content-Type', media.mimeType);
    res.setHeader('Content-Length', media.size.toString());
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    return res.send(media.data);
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
