import { IsEmail, MaxLength } from 'class-validator';
import { Trim } from '../../common/decorators/trim.decorator';

export class RequestPasswordResetDto {
  @Trim()
  @IsEmail()
  @MaxLength(120)
  email: string;
}
