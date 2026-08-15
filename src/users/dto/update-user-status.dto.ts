import { IsIn } from 'class-validator';

export class UpdateUserStatusDto {
  @IsIn(['ACTIVE', 'INACTIVE', 'SUSPENDED'])
  status: 'ACTIVE' | 'INACTIVE' | 'SUSPENDED';
}
