import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';
import { Trim } from '../../common/decorators/trim.decorator';

export class LoginDto {
  @Trim()
  @IsEmail()
  @MaxLength(120)
  email: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;
}
