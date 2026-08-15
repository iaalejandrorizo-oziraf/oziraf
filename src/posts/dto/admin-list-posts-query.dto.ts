import { IsIn, IsOptional } from 'class-validator';
import { ListPostsQueryDto } from './list-posts-query.dto';

export class AdminListPostsQueryDto extends ListPostsQueryDto {
  @IsOptional()
  @IsIn(['ACTIVE', 'INACTIVE', 'DELETED'])
  status?: 'ACTIVE' | 'INACTIVE' | 'DELETED';
}
