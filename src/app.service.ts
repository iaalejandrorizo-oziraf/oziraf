import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHealth() {
    return {
      name: 'OZIRAF API',
      status: 'ok',
      version: '4.6',
    };
  }
}
