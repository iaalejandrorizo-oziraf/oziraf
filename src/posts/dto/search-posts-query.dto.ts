import { IsOptional, IsString, MaxLength } from 'class-validator';
import { Trim } from '../../common/decorators/trim.decorator';
import { ListPostsQueryDto } from './list-posts-query.dto';

export class SearchPostsQueryDto extends ListPostsQueryDto {
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(120)
  q?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  category?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  country?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  state?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  city?: string;
}
