import {
  Body,
  Controller,
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
}
