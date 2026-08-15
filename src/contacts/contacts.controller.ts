import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ContactsService } from './contacts.service';
import { CreateContactLeadDto } from './dto/create-contact-lead.dto';

@UseGuards(JwtAuthGuard)
@Controller('contacts')
export class ContactsController {
  constructor(private contactsService: ContactsService) {}

  @Post('posts/:postId')
  async create(
    @Param('postId') postId: string,
    @Request() req,
    @Body() createContactLeadDto: CreateContactLeadDto,
  ) {
    return this.contactsService.create(
      postId,
      req.user.userId,
      createContactLeadDto,
    );
  }

  @Get('leads')
  async findReceived(@Request() req) {
    return this.contactsService.findReceived(req.user.userId);
  }
}
