import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import dotenv from 'dotenv';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.resolve(currentDir, '..', '..');
const repoRoot = path.resolve(backendRoot, '..');
const candidateEnvFiles = [
  path.join(repoRoot, '.env'),
  path.join(backendRoot, '.env'),
];

for (const envFile of candidateEnvFiles) {
  if (fs.existsSync(envFile)) {
    dotenv.config({ path: envFile, override: false });
  }
}

export const env = {
  port: process.env.PORT || '4000',
  mongodbUri: process.env.MONGODB_URI || '',
  jwtSecret: process.env.JWT_SECRET || 'change-me',
  clientOrigin: process.env.CLIENT_ORIGIN || '*',
  defaultAdminEmail: process.env.DEFAULT_ADMIN_EMAIL || 'aman@indofeast.com',
  defaultAdminPassword: process.env.DEFAULT_ADMIN_PASSWORD || 'Amazing12@',
  defaultAdminName: process.env.DEFAULT_ADMIN_NAME || 'Aman IndoFeast',
  razorpayKeyId: process.env.RAZORPAY_KEY_ID || '',
  razorpayKeySecret: process.env.RAZORPAY_KEY_SECRET || '',
  cashfreeClientId: process.env.CASHFREE_CLIENT_ID || '',
  cashfreeClientSecret: process.env.CASHFREE_CLIENT_SECRET || '',
  cashfreeApiVersion: process.env.CASHFREE_API_VERSION || '2025-01-01',
  cashfreeBaseUrl: process.env.CASHFREE_BASE_URL || 'https://sandbox.cashfree.com/pg',
  stripeSecretKey: process.env.STRIPE_SECRET_KEY || '',
  stripePublishableKey: process.env.STRIPE_PUBLISHABLE_KEY || '',
};
