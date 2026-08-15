import { IsIn, IsOptional } from 'class-validator';
import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';

export class ListReportsQueryDto extends PaginationQueryDto {
  @IsOptional()
  @IsIn(['OPEN', 'REVIEWED', 'RESOLVED', 'DISMISSED'])
  status?: 'OPEN' | 'REVIEWED' | 'RESOLVED' | 'DISMISSED';
}
