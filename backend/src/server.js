import { createApp } from './app.js';
import { connectDatabase } from './config/db.js';
import { env } from './config/env.js';
import { ensureDefaultAdmin } from './services/admin-seed-service.js';
import { ensureCustomerCatalog } from './services/customer-seed-service.js';
import { ensureDemoUsers } from './services/demo-users-seed-service.js';

async function start() {
  const connected = await connectDatabase();
  if (connected) {
    await ensureDefaultAdmin();
    await ensureCustomerCatalog();
    await ensureDemoUsers();
  }

  const app = createApp();
  app.listen(env.port, () => {
    console.log(`IndoFeast backend listening on http://localhost:${env.port}`);
  });
}

start().catch((error) => {
  console.error('Failed to start IndoFeast backend', error);
  process.exit(1);
});
