const CATEGORY_DECISIONS = Object.freeze({
  accounts: 'inactiveAccountPeriod',
  transactions: 'transactionalRecordPeriod',
  communications: 'communicationPeriod',
  handoverEvidence: 'transactionalRecordPeriod',
  moderation: 'moderationEvidencePeriod',
  securityAudit: 'auditSecurityLogPeriod',
  legalHold: 'legalHoldProcess',
});

export class RetentionInventoryError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

function iso(value) {
  if (value === null || value === undefined) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function count(value) {
  const parsed = Number.parseInt(value, 10);
  return Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : 0;
}

function shapeRows(rows) {
  const grouped = new Map();
  for (const row of rows) {
    const category = String(row.category ?? '');
    const decisionKey = CATEGORY_DECISIONS[category];
    if (!decisionKey) throw new RetentionInventoryError(500, 'unexpected_retention_category');
    const entry = grouped.get(category) ?? {
      category,
      decisionKey,
      policyStatus: 'open',
      cutoffApplied: false,
      eligibleRows: null,
      totalRows: 0,
      datasets: [],
    };
    const rowCount = count(row.row_count);
    entry.totalRows += rowCount;
    entry.datasets.push({
      dataset: String(row.dataset ?? ''),
      totalRows: rowCount,
      oldestAt: iso(row.oldest_at),
      newestAt: iso(row.newest_at),
    });
    grouped.set(category, entry);
  }
  return [...grouped.values()].sort((left, right) => left.category.localeCompare(right.category));
}

export async function inspectRetentionInventory(client, { actor }) {
  if (actor?.role !== 'admin') throw new RetentionInventoryError(403, 'admin_role_required');
  const result = await client.query(
    `WITH inventory(category, dataset, row_count, oldest_at, newest_at) AS (
       SELECT 'accounts', 'user_accounts', count(*)::bigint, min(created_at), max(updated_at) FROM users
       UNION ALL SELECT 'transactions', 'bookings', count(*)::bigint, min(created_at), max(updated_at) FROM bookings
       UNION ALL SELECT 'transactions', 'booking_quotes', count(*)::bigint, min(issued_at), max(issued_at) FROM booking_quotes
       UNION ALL SELECT 'transactions', 'legal_document_snapshots', count(*)::bigint, min(created_at), max(created_at) FROM legal_document_snapshots
       UNION ALL SELECT 'transactions', 'platform_contracts', count(*)::bigint, min(created_at), max(created_at) FROM platform_contracts
       UNION ALL SELECT 'transactions', 'platform_contract_declarations', count(*)::bigint, min(created_at), max(created_at) FROM platform_contract_declarations
       UNION ALL SELECT 'transactions', 'platform_contract_receipts', count(*)::bigint, min(generated_at), max(generated_at) FROM platform_contract_receipts
       UNION ALL SELECT 'transactions', 'platform_contract_receipt_events', count(*)::bigint, min(occurred_at), max(occurred_at) FROM platform_contract_receipt_events
       UNION ALL SELECT 'transactions', 'payments', count(*)::bigint, min(created_at), max(updated_at) FROM payments
       UNION ALL SELECT 'transactions', 'refunds', count(*)::bigint, min(created_at), max(updated_at) FROM refunds
       UNION ALL SELECT 'transactions', 'payouts', count(*)::bigint, min(created_at), max(updated_at) FROM payouts
       UNION ALL SELECT 'transactions', 'disputes', count(*)::bigint, min(created_at), max(updated_at) FROM disputes
       UNION ALL SELECT 'communications', 'messages', count(*)::bigint, min(created_at), max(created_at) FROM messages
       UNION ALL SELECT 'communications', 'notifications', count(*)::bigint, min(created_at), max(created_at) FROM notifications
       UNION ALL SELECT 'communications', 'notification_outbox', count(*)::bigint, min(created_at), max(updated_at) FROM notification_outbox
       UNION ALL SELECT 'communications', 'message_attachments', count(*)::bigint, min(created_at), max(created_at)
         FROM uploads WHERE purpose = 'message_attachment'
       UNION ALL SELECT 'handoverEvidence', 'handover_return_evidence', count(*)::bigint, min(created_at), max(created_at)
         FROM uploads WHERE purpose IN ('handover_evidence', 'return_evidence')
       UNION ALL SELECT 'moderation', 'reports', count(*)::bigint, min(created_at), max(updated_at) FROM reports
       UNION ALL SELECT 'moderation', 'report_evidence', count(*)::bigint, min(created_at), max(created_at) FROM report_evidence
       UNION ALL SELECT 'moderation', 'moderation_case_events', count(*)::bigint, min(created_at), max(created_at) FROM moderation_case_events
       UNION ALL SELECT 'moderation', 'moderation_actions', count(*)::bigint, min(created_at), max(created_at) FROM moderation_actions
       UNION ALL SELECT 'moderation', 'user_suspensions', count(*)::bigint, min(created_at), max(created_at) FROM user_suspensions
       UNION ALL SELECT 'securityAudit', 'audit_log', count(*)::bigint, min(created_at), max(created_at) FROM audit_log
       UNION ALL SELECT 'securityAudit', 'booking_events', count(*)::bigint, min(created_at), max(created_at) FROM booking_events
       UNION ALL SELECT 'securityAudit', 'notification_delivery_attempts', count(*)::bigint, min(created_at), max(created_at)
         FROM notification_delivery_attempts
       UNION ALL SELECT 'securityAudit', 'auth_sessions', count(*)::bigint, min(created_at), max(last_seen_at) FROM auth_sessions
       UNION ALL SELECT 'legalHold', 'account_legal_holds', count(*)::bigint, min(created_at), max(COALESCE(released_at, created_at))
         FROM account_legal_holds
     )
     SELECT category, dataset, row_count, oldest_at, newest_at
     FROM inventory ORDER BY category, dataset`,
  );
  const categories = shapeRows(result.rows);
  const totalRows = categories.reduce((sum, category) => sum + category.totalRows, 0);
  await client.query(
    `INSERT INTO audit_log (actor_id, actor_role, action, resource_type, resource_id, metadata)
     VALUES ($1, $2, 'privacy.retention_inventory_viewed', 'privacy', 'retention-inventory', $3::jsonb)`,
    [actor.id, actor.role, JSON.stringify({
      categoryCount: categories.length,
      datasetCount: categories.reduce((sum, category) => sum + category.datasets.length, 0),
      totalRows,
      executionEnabled: false,
    })],
  );
  return {
    status: 'policy-open-inventory-only',
    generatedAt: new Date().toISOString(),
    containsIdentifiers: false,
    executionEnabled: false,
    retentionPeriodsApplied: false,
    eligibleRowsCalculated: false,
    categories,
  };
}
