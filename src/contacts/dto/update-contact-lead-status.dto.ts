import { IsIn } from 'class-validator';

export class UpdateContactLeadStatusDto {
  @IsIn(['NEW', 'READ', 'ARCHIVED'])
  status: 'NEW' | 'READ' | 'ARCHIVED';
}
