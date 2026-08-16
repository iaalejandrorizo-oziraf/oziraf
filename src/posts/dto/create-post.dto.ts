import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUrl,
  Max,
  Min,
  ArrayMaxSize,
  IsArray,
  MaxLength,
} from 'class-validator';
import { Trim } from '../../common/decorators/trim.decorator';

export class CreatePostDto {
  @Trim()
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  title: string;

  @Trim()
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  description: string;

  @Trim()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  category: string;

  @Trim()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  country: string;

  @Trim()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  city: string;

  @Trim()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  state: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(80)
  neighborhood?: string;

  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(200)
  address?: string;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsUrl({ require_protocol: true }, { each: true })
  imageUrls?: string[];

  @IsOptional()
  @IsNumber()
  @IsPositive()
  price?: number;
}
