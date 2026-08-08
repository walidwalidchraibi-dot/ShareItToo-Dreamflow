import http from 'node:http';

import { createApp } from './app.js';
import { config } from './config.js';
import { initializeDatabase, pool } from './db.js';
import { attachRealtime } from './realtime.js';
import { verifyMailer } from './mailer.js';
import { seedPublicCatalog } from './seed.js';

async function main() {
  await initializeDatabase();
  await seedPublicCatalog();
  await verifyMailer();

  const app = createApp();
  const server = http.createServer(app);
  attachRealtime(server);

  server.listen(config.port, '0.0.0.0', () => {
    console.log(`[shareittoo-api] listening on :${config.port}`);
  });

  const shutdown = async (signal) => {
    console.log(`[shareittoo-api] ${signal}, shutting down`);
    server.close(async () => {
      await pool.end();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main().catch((error) => {
  console.error('[shareittoo-api] startup failed', error);
  process.exit(1);
});
