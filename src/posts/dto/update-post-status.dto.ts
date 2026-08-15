import { IsIn } from 'class-validator';

export class UpdatePostStatusDto {
  @IsIn(['ACTIVE', 'INACTIVE'])
  status: 'ACTIVE' | 'INACTIVE';
}
