import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class FavoriteParamDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  postId: string;
}
