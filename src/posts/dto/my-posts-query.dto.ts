import { IsIn, IsOptional } from 'class-validator';
import { ListPostsQueryDto } from './list-posts-query.dto';

export class MyPostsQueryDto extends ListPostsQueryDto {
  @IsOptional()
  @IsIn(['ACTIVE', 'INACTIVE'])
  status?: 'ACTIVE' | 'INACTIVE';
}
