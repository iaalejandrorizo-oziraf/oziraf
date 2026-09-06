import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';

export type MediaStorageDriver = 'DATABASE' | 'LOCAL';

@Injectable()
export class MediaStorageService {
  private readonly logger = new Logger(MediaStorageService.name);

  get driver(): MediaStorageDriver {
    return process.env.MEDIA_STORAGE_DRIVER?.trim().toUpperCase() === 'LOCAL'
      ? 'LOCAL'
      : 'DATABASE';
  }

  usesLocalStorage() {
    return this.driver === 'LOCAL';
  }

  createKey(postId: string) {
    return `posts/${postId}/${randomUUID()}`;
  }

  async write(key: string, data: Buffer) {
    const target = this.resolveKey(key);
    await mkdir(dirname(target), { recursive: true });

    const temporary = `${target}.${randomUUID()}.upload`;
    await writeFile(temporary, data, { flag: 'wx' });
    await rename(temporary, target);
  }

  async read(key: string) {
    try {
      return await readFile(this.resolveKey(key));
    } catch (error) {
      if (this.isFileNotFound(error)) {
        throw new NotFoundException('El archivo no existe');
      }
      throw error;
    }
  }

  async remove(key: string) {
    try {
      await rm(this.resolveKey(key), { force: true });
    } catch (error) {
      this.logger.warn(`No se pudo eliminar el archivo local ${key}`);
      if (!this.isFileNotFound(error)) {
        throw error;
      }
    }
  }

  private get rootPath() {
    const configuredPath = process.env.MEDIA_STORAGE_PATH?.trim();
    return resolve(configuredPath || join(process.cwd(), 'storage', 'media'));
  }

  private resolveKey(key: string) {
    const root = this.rootPath;
    const target = resolve(root, key);
    const pathFromRoot = relative(root, target);

    if (
      !key ||
      isAbsolute(key) ||
      pathFromRoot === '' ||
      pathFromRoot.startsWith('..') ||
      isAbsolute(pathFromRoot)
    ) {
      throw new Error('La ruta del archivo no es válida');
    }

    return target;
  }

  private isFileNotFound(error: unknown) {
    return (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      error.code === 'ENOENT'
    );
  }
}
