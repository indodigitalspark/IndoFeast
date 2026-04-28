import mongoose from 'mongoose';

import { env } from './env.js';

let databaseConnected = false;
let demoMode = false;

export async function connectDatabase() {
  if (!env.mongodbUri) {
    demoMode = true;
    console.warn('MONGODB_URI is missing. Starting IndoFeast backend in demo mode.');
    return false;
  }

  try {
    await mongoose.connect(env.mongodbUri);
    databaseConnected = true;
    demoMode = false;
    return true;
  } catch (error) {
    demoMode = true;
    console.warn(
      'MongoDB connection failed. Starting IndoFeast backend in demo mode.',
      error?.message || error,
    );
    return false;
  }
}

export function isDatabaseConnected() {
  return databaseConnected;
}

export function isDemoModeEnabled() {
  return demoMode;
}
