import { IsIn } from 'class-validator';

export class AdminUpdatePostStatusDto {
  @IsIn(['ACTIVE', 'INACTIVE', 'DELETED'])
  status: 'ACTIVE' | 'INACTIVE' | 'DELETED';
}
