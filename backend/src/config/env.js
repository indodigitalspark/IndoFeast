import dotenv from 'dotenv';

dotenv.config();

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
