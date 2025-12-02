import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, UnauthorizedException, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { UploadsModule } from './uploads.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { join } from 'path';
import { rmSync, writeFileSync, mkdirSync } from 'fs';
import { UploadsService } from './uploads.service';

class HeaderJwtGuard {
  canActivate(ctx: any) {
    const req = ctx.switchToHttp().getRequest();
    if (!req.headers.authorization) {
      throw new UnauthorizedException();
    }
    req.user = { userId: 1, role: 'CLIENT' };
    return true;
  }
}

describe('UploadsController (e2e)', () => {
  let app: INestApplication;
  let uploadsPath: string;

  beforeAll(async () => {
    uploadsPath = join(process.cwd(), 'uploads-test');
    process.env.UPLOAD_DIR = 'uploads-test';

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [UploadsModule],
    })
      .overrideGuard(JwtAuthGuard)
      .useClass(HeaderJwtGuard)
      .compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
      }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
    rmSync(uploadsPath, { recursive: true, force: true });
    delete process.env.UPLOAD_DIR;
  });

  it('rejects access without auth header', async () => {
    await request(app.getHttpServer()).get('/uploads/somefile.jpg').expect(401);
  });

  it('rejects uploads with invalid mime type', async () => {
    await request(app.getHttpServer())
      .post('/uploads')
      .set('Authorization', 'Bearer test')
      .attach('file', Buffer.from('hello'), {
        filename: 'note.txt',
        contentType: 'text/plain',
      })
      .expect(400);
  });

  it('rejects uploads that exceed size limit', async () => {
    await request(app.getHttpServer())
      .post('/uploads')
      .set('Authorization', 'Bearer test')
      .attach('file', Buffer.alloc(6 * 1024 * 1024), {
        filename: 'big.jpg',
        contentType: 'image/jpeg',
      })
      .expect(400);
  });

  it('blocks path traversal attempts', async () => {
    await request(app.getHttpServer())
      .get('/uploads/..%2Fmain.ts')
      .set('Authorization', 'Bearer test')
      .expect(400);
  });

  it('serves an uploaded file with auth', async () => {
    const service = app.get(UploadsService);
    service.ensureUploadsDir();
    const targetFile = join(uploadsPath, 'sample.jpg');
    mkdirSync(uploadsPath, { recursive: true });
    writeFileSync(targetFile, 'image');

    await request(app.getHttpServer())
      .get('/uploads/sample.jpg')
      .set('Authorization', 'Bearer test')
      .expect(200);
  });

  describe('public endpoint security', () => {
    it('allows access to UUID-pattern image files publicly', async () => {
      const service = app.get(UploadsService);
      service.ensureUploadsDir();
      const uuidFilename = '12345678-1234-1234-1234-123456789abc.jpg';
      const targetFile = join(uploadsPath, uuidFilename);
      mkdirSync(uploadsPath, { recursive: true });
      writeFileSync(targetFile, 'public-image');

      await request(app.getHttpServer())
        .get(`/uploads/public/${uuidFilename}`)
        .expect(200);
    });

    it('blocks public access to PDF files', async () => {
      const service = app.get(UploadsService);
      service.ensureUploadsDir();
      const pdfFilename = '12345678-1234-1234-1234-123456789abc.pdf';
      const targetFile = join(uploadsPath, pdfFilename);
      mkdirSync(uploadsPath, { recursive: true });
      writeFileSync(targetFile, 'private-doc');

      await request(app.getHttpServer())
        .get(`/uploads/public/${pdfFilename}`)
        .expect(404); // Not found or not publicly accessible
    });

    it('blocks public access to non-UUID filenames', async () => {
      const service = app.get(UploadsService);
      service.ensureUploadsDir();
      const regularFilename = 'avatar.jpg';
      const targetFile = join(uploadsPath, regularFilename);
      mkdirSync(uploadsPath, { recursive: true });
      writeFileSync(targetFile, 'should-not-access');

      await request(app.getHttpServer())
        .get(`/uploads/public/${regularFilename}`)
        .expect(404);
    });

    it('blocks path traversal attempts on public endpoint', async () => {
      await request(app.getHttpServer())
        .get('/uploads/public/..%2F..%2Fmain.ts')
        .expect(404);
    });
  });
});
