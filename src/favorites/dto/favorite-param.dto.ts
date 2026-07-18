import { IsString } from 'class-validator';

export class FavoriteParamDto {
  @IsString()
  postId: string;
}
