import {
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  MinLength,
} from 'class-validator';
import { Trim } from '../../common/decorators/trim.decorator';

export class RegisterDto {
  @Trim()
  @IsEmail()
  @MaxLength(120)
  email: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;

  @Trim()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  firstName: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  lastName?: string;

  @IsOptional()
  @IsIn(['SOLICITANTE', 'ANUNCIANTE'])
  accountType?: string;

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
  tiktokUrl?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @IsUrl({ require_protocol: true })
  @MaxLength(500)
  xUrl?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @IsUrl({ require_protocol: true })
  @MaxLength(500)
  websiteUrl?: string;
}
