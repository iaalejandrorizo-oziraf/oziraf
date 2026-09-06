import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { MediaStorageService } from './media-storage.service';

describe('MediaStorageService', () => {
  const originalDriver = process.env.MEDIA_STORAGE_DRIVER;
  const originalPath = process.env.MEDIA_STORAGE_PATH;
  let storagePath: string;

  beforeEach(async () => {
    storagePath = await mkdtemp(join(tmpdir(), 'oziraf-media-'));
    process.env.MEDIA_STORAGE_DRIVER = 'LOCAL';
    process.env.MEDIA_STORAGE_PATH = storagePath;
  });

  afterEach(async () => {
    await rm(storagePath, { recursive: true, force: true });
    restoreEnvironment('MEDIA_STORAGE_DRIVER', originalDriver);
    restoreEnvironment('MEDIA_STORAGE_PATH', originalPath);
  });

  it('writes, reads and removes a local media file', async () => {
    const service = new MediaStorageService();
    const key = service.createKey('post-1');
    const data = Buffer.from('media-content');

    await service.write(key, data);

    await expect(service.read(key)).resolves.toEqual(data);
    await service.remove(key);
    await expect(service.read(key)).rejects.toThrow('El archivo no existe');
  });

  it('rejects a storage key outside the configured media folder', async () => {
    const service = new MediaStorageService();

    await expect(
      service.write('../outside', Buffer.from('no')),
    ).rejects.toThrow('La ruta del archivo no es válida');
  });
});

function restoreEnvironment(name: string, value: string | undefined) {
  if (value === undefined) {
    delete process.env[name];
    return;
  }

  process.env[name] = value;
}
