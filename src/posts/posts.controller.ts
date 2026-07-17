import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';

import { PostsService } from './posts.service';
import { CreatePostDto } from './dto/create-post.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('posts')
export class PostsController {
  constructor(private postsService: PostsService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  async create(
    @Request() req,
    @Body() createPostDto: CreatePostDto,
  ) {
    return this.postsService.create(
      req.user.userId,
      createPostDto,
    );
  }

  @Get()
  async findAll() {
    return this.postsService.findAll();
  }

  @Get(':id')
  async findOne(
    @Param('id') id: string,
  ) {
    return this.postsService.findOne(id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Request() req,
    @Body() createPostDto: CreatePostDto,
  ) {
    return this.postsService.update(
      id,
      req.user.userId,
      createPostDto,
    );
  }
  @UseGuards(JwtAuthGuard)
@Delete(':id')
async remove(
  @Param('id') id: string,
  @Request() req,
) {
  return this.postsService.remove(
    id,
    req.user.userId,
  );
}
}