import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class UploadProfilePhotoDto {
  @IsString()
  @IsIn(['image/jpeg', 'image/png', 'image/webp'])
  mimeType: string;

  @IsString()
  @MinLength(20)
  @MaxLength(2_100_000)
  imageBase64: string;
}
