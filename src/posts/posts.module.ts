import { Module } from '@nestjs/common';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';
import { PrismaModule } from '../prisma/prisma.module';
import { MediaStorageModule } from '../media-storage/media-storage.module';

@Module({
  imports: [PrismaModule, MediaStorageModule],
  controllers: [PostsController],
  providers: [PostsService],
  exports: [PostsService],
})
export class PostsModule {}
