import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateReviewDto } from './dto/create-review.dto';
import { ListReviewsQueryDto } from './dto/list-reviews-query.dto';
import { ReviewsService } from './reviews.service';

@Controller('reviews')
export class ReviewsController {
  constructor(private reviewsService: ReviewsService) {}

  @UseGuards(JwtAuthGuard)
  @Post('posts/:postId')
  async create(
    @Param('postId') postId: string,
    @Request() req,
    @Body() createReviewDto: CreateReviewDto,
  ) {
    return this.reviewsService.create(postId, req.user.userId, createReviewDto);
  }

  @Get('posts/:postId')
  async findByPost(
    @Param('postId') postId: string,
    @Query() query: ListReviewsQueryDto,
  ) {
    return this.reviewsService.findByPost(postId, query);
  }
}
