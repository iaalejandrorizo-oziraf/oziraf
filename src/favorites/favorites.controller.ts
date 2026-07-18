import {
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { FavoriteParamDto } from './dto/favorite-param.dto';
import { FavoritesService } from './favorites.service';

@UseGuards(JwtAuthGuard)
@Controller('favorites')
export class FavoritesController {
  constructor(private favoritesService: FavoritesService) {}

  @Post(':postId')
  async create(@Request() req, @Param() params: FavoriteParamDto) {
    return this.favoritesService.create(req.user.userId, params.postId);
  }

  @Delete(':postId')
  async remove(@Request() req, @Param() params: FavoriteParamDto) {
    return this.favoritesService.remove(req.user.userId, params.postId);
  }

  @Get()
  async findAll(@Request() req) {
    return this.favoritesService.findAll(req.user.userId);
  }
}
