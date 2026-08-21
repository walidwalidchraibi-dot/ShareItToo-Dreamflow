import http from 'node:http';

import { createApp } from './app.js';
import { config } from './config.js';
import { startCredentialCleanupWorker } from './credential_cleanup.js';
import { startFirebaseIdentityCleanupWorker } from './firebase_identity_cleanup.js';
import {
  createCrashlyticsReportDeleteClient,
  startCrashlyticsCleanupWorker,
} from './crashlytics_cleanup.js';
import { initializeDatabase, pool } from './db.js';
import { attachRealtime } from './realtime.js';
import { verifyMailer } from './mailer.js';
import { drainNotificationOutbox } from './notifications.js';
import { reconcilePaymentLifecycle } from './payment_workflow.js';
import { reconcileReturnLifecycle } from './return_lifecycle_workflow.js';
import { reconcileSupportDeadlines } from './support_deadline_watchdog.js';

async function main() {
  await initializeDatabase();
  await verifyMailer();

  const app = createApp();
  const server = http.createServer(app);
  attachRealtime(server);

  server.listen(config.port, '0.0.0.0', () => {
    console.log(`[shareittoo-api] listening on :${config.port}`);
  });
  const notificationTimer = setInterval(() => {
    void drainNotificationOutbox().catch((error) => {
      console.error('[notifications] worker failed', error?.message ?? error);
    });
  }, config.notifications.workerIntervalMs);
  notificationTimer.unref();
  void drainNotificationOutbox().catch((error) => {
    console.error('[notifications] startup drain failed', error?.message ?? error);
  });
  const returnLifecycleTimer = setInterval(() => {
    void reconcileReturnLifecycle().then(() => drainNotificationOutbox()).catch((error) => {
      console.error('[return-lifecycle] reconciliation failed', error?.code ?? error?.message ?? error);
    });
  }, config.returnLifecycle.workerIntervalMs);
  returnLifecycleTimer.unref();
  void reconcileReturnLifecycle().then(() => drainNotificationOutbox()).catch((error) => {
    console.error('[return-lifecycle] startup reconciliation failed', error?.code ?? error?.message ?? error);
  });
  const supportDeadlineTimer = setInterval(() => {
    void reconcileSupportDeadlines().catch((error) => {
      console.error('[support-deadline-watchdog] reconciliation failed', error?.code ?? error?.message ?? error);
    });
  }, config.supportDeadlines.workerIntervalMs);
  supportDeadlineTimer.unref();
  void reconcileSupportDeadlines().catch((error) => {
    console.error('[support-deadline-watchdog] startup reconciliation failed', error?.code ?? error?.message ?? error);
  });
  const paymentTimer = setInterval(() => {
    void reconcilePaymentLifecycle().catch((error) => {
      console.error('[payments] reconciliation failed', error?.code ?? error?.message ?? error);
    });
  }, 30_000);
  paymentTimer.unref();
  void reconcilePaymentLifecycle().catch((error) => {
    console.error('[payments] startup reconciliation failed', error?.code ?? error?.message ?? error);
  });
  const stopCredentialCleanup = startCredentialCleanupWorker({ client: pool });
  const stopFirebaseIdentityCleanup = startFirebaseIdentityCleanupWorker({
    client: pool,
  });
  const stopCrashlyticsCleanup = config.crashReportDeletion.enabled
    ? startCrashlyticsCleanupWorker({
      client: pool,
      deleteReports: createCrashlyticsReportDeleteClient({
        projectId: config.crashReportDeletion.firebaseProjectId,
        serviceAccountFile: config.crashReportDeletion.firebaseServiceAccountFile,
      }),
    })
    : () => {};

  const shutdown = async (signal) => {
    console.log(`[shareittoo-api] ${signal}, shutting down`);
    clearInterval(notificationTimer);
    clearInterval(returnLifecycleTimer);
    clearInterval(supportDeadlineTimer);
    clearInterval(paymentTimer);
    stopCredentialCleanup();
    stopFirebaseIdentityCleanup();
    stopCrashlyticsCleanup();
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
