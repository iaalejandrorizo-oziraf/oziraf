import { IsIn, IsOptional } from 'class-validator';
import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';

export class ListContactLeadsQueryDto extends PaginationQueryDto {
  @IsOptional()
  @IsIn(['NEW', 'READ', 'ARCHIVED'])
  status?: 'NEW' | 'READ' | 'ARCHIVED';
}
