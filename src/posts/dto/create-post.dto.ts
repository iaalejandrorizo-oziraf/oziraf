import {
  IsString,
  IsOptional,
  IsNumber,
} from 'class-validator';

export class CreatePostDto {
  @IsString()
  title: string;

  @IsString()
  description: string;

  @IsString()
  category: string;

  @IsString()
  city: string;

  @IsString()
  state: string;

  @IsOptional()
  @IsString()
  neighborhood?: string;

  @IsOptional()
  @IsNumber()
  price?: number;
}