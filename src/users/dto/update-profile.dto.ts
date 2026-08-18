import { IsIn, IsOptional, IsString, IsUrl, MaxLength } from 'class-validator';
import { Trim } from '../../common/decorators/trim.decorator';

export class UpdateProfileDto {
  @IsOptional()
  @IsIn(['SOLICITANTE', 'ANUNCIANTE'])
  accountType?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  firstName?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  lastName?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  city?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  state?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  neighborhood?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(100)
  profession?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @IsUrl({ require_protocol: true })
  @MaxLength(500)
  profilePhoto?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(30)
  whatsapp?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @IsUrl({ require_protocol: true })
  @MaxLength(500)
  instagramUrl?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @IsUrl({ require_protocol: true })
  @MaxLength(500)
  facebookUrl?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @IsUrl({ require_protocol: true })
  @MaxLength(500)
  websiteUrl?: string;
}
