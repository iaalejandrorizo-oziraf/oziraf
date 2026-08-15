import { IsIn } from 'class-validator';

export class UpdateReportStatusDto {
  @IsIn(['OPEN', 'REVIEWED', 'RESOLVED', 'DISMISSED'])
  status: 'OPEN' | 'REVIEWED' | 'RESOLVED' | 'DISMISSED';
}
