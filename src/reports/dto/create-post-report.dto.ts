import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { Trim } from '../../common/decorators/trim.decorator';

export class CreatePostReportDto {
  @Trim()
  @IsString()
  @IsIn(['SPAM', 'FRAUD', 'INAPPROPRIATE', 'OTHER'])
  reason: 'SPAM' | 'FRAUD' | 'INAPPROPRIATE' | 'OTHER';

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(500)
  details?: string;
}
