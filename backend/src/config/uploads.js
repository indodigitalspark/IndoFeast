import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import multer from 'multer';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.resolve(currentDir, '..', '..');
const localUploadDir = path.join(backendRoot, 'uploads');
const serverlessUploadDir = path.join(os.tmpdir(), 'indofeast-uploads');

function isServerlessRuntime() {
  return Boolean(process.env.VERCEL || process.env.AWS_LAMBDA_FUNCTION_NAME);
}

export const uploadDirectory = isServerlessRuntime()
  ? serverlessUploadDir
  : localUploadDir;

fs.mkdirSync(uploadDirectory, { recursive: true });

export const upload = multer({ dest: uploadDirectory });
