import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { Trim } from '../../common/decorators/trim.decorator';

export class CreateUserReportDto {
  @Trim()
  @IsString()
  @IsIn(['HARASSMENT', 'FRAUD', 'IMPERSONATION', 'DANGEROUS', 'OTHER'])
  reason: 'HARASSMENT' | 'FRAUD' | 'IMPERSONATION' | 'DANGEROUS' | 'OTHER';

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(500)
  details?: string;
}
