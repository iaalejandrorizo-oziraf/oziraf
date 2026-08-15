import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
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
  @IsNumber()
  @IsPositive()
  price?: number;
}
