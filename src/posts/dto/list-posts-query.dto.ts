import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';
import { IsIn, IsOptional } from 'class-validator';

export class ListPostsQueryDto extends PaginationQueryDto {
  @IsOptional()
  @IsIn(['createdAt', 'price'])
  sortBy?: 'createdAt' | 'price';

  @IsOptional()
  @IsIn(['asc', 'desc'])
  sortOrder?: 'asc' | 'desc';
}
