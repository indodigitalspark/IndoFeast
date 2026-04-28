import { createApp } from './app.js';
import { connectDatabase } from './config/db.js';
import { ensureDefaultAdmin } from './services/admin-seed-service.js';
import { ensureCustomerCatalog } from './services/customer-seed-service.js';
import { ensureDemoUsers } from './services/demo-users-seed-service.js';

let bootPromise;

async function bootBackend() {
  if (!bootPromise) {
    bootPromise = (async () => {
      const connected = await connectDatabase();
      if (connected) {
        await ensureDefaultAdmin();
        await ensureCustomerCatalog();
        await ensureDemoUsers();
      }
      return createApp();
    })();
  }

  return bootPromise;
}

const app = await bootBackend();

export default app;
