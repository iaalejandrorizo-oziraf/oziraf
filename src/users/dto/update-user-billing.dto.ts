import { IsDateString, IsIn, IsOptional } from 'class-validator';

export class UpdateUserBillingDto {
  @IsIn(['TRIAL', 'PAID', 'DUE', 'OVERDUE', 'EXEMPT'])
  billingStatus: 'TRIAL' | 'PAID' | 'DUE' | 'OVERDUE' | 'EXEMPT';

  @IsOptional()
  @IsDateString()
  renewalDueAt?: string;
}
