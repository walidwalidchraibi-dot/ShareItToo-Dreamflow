async function rows(client, sql, userId) {
  const result = await client.query(sql, [userId]);
  return result.rows;
}

export async function buildAccountExport(client, userId) {
  const accountResult = await client.query(
    `SELECT id, email, profile, role, account_status, phone_e164,
            email_verified_at, phone_verified_at, terms_accepted_at,
            privacy_accepted_at, minimum_age_confirmed_at, created_at,
            updated_at, password_changed_at
     FROM users WHERE id = $1`,
    [userId],
  );

  const account = accountResult.rows[0];
  if (!account) return null;

  const [
    sessions,
    identities,
    pushDevices,
    listings,
    bookings,
    bookingQuotes,
    platformContracts,
    platformContractDeclarations,
    platformContractReceipts,
    platformContractReceiptEvents,
    withdrawals,
    withdrawalRefundObligations,
    withdrawalRefundObligationEvents,
    cancellationRefundObligations,
    withdrawalReceipts,
    withdrawalReceiptEvents,
    messageThreads,
    messages,
    uploads,
    bookingConditionEvidence,
    bookingConditionConfirmations,
    notificationPreferences,
    notifications,
    reviews,
    reports,
    blocks,
    payments,
    refunds,
    payouts,
    financialDocuments,
    financialDocumentEvents,
    depositMandates,
    depositCharges,
    disputes,
    auditEvents,
  ] = await Promise.all([
    rows(client,
      `SELECT id, device_label, user_agent, host(ip_address) AS ip_address,
              created_at, last_seen_at, revoked_at, revoked_reason
       FROM auth_sessions WHERE user_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT provider, provider_subject, firebase_user_id, email_at_link, email_verified,
              created_at, last_login_at
       FROM auth_identities WHERE user_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT id, platform, locale, enabled, created_at, last_seen_at
       FROM push_devices WHERE user_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT id, payload, status, is_active, currency, price_per_day_minor,
              security_deposit_minor, moderation_status,
              moderation_reason_code, created_at, updated_at
       FROM listings WHERE owner_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT id, listing_id,
              CASE WHEN owner_id = $1 THEN 'owner' ELSE 'renter' END AS my_role,
              status, starts_at, ends_at, currency, rental_subtotal_minor,
              platform_fee_minor, owner_payout_minor, quoted_total_minor,
              security_deposit_minor, created_at, updated_at
       FROM bookings WHERE owner_id = $1 OR renter_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT id, listing_id, rental_start_date, rental_end_date,
              rental_timezone, catalog_revision, availability_revision,
              quote_version, currency, total_minor, quote_payload,
              quote_hash, issued_at, expires_at
       FROM booking_quotes WHERE renter_id = $1 ORDER BY issued_at`, userId),
    rows(client,
      `SELECT contract.id, contract.booking_id, contract.quote_id,
              contract.quote_hash, contract.contract_version, contract.locale,
              contract.client_build, contract.accepted_at, contract.created_at,
              contract.sit_acceptance_wording,
              contract.sit_acceptance_sha256,
              platform_terms.content_sha256 AS platform_terms_sha256,
              private_terms.content_sha256 AS private_rental_terms_sha256,
              cancellation_refund.content_sha256 AS cancellation_refund_sha256,
              handover_return_damage.content_sha256 AS handover_return_damage_sha256,
              payment_payout.content_sha256 AS payment_payout_sha256,
              community_safety.content_sha256 AS community_safety_sha256,
              reporting_moderation.content_sha256 AS reporting_moderation_review_sha256,
              privacy.content_sha256 AS privacy_sha256,
              imprint_withdrawal.content_sha256 AS imprint_withdrawal_shorttexts_sha256
       FROM platform_contracts AS contract
       JOIN legal_document_snapshots AS platform_terms
         ON platform_terms.id = contract.platform_terms_snapshot_id
       JOIN legal_document_snapshots AS private_terms
         ON private_terms.id = contract.private_rental_terms_snapshot_id
       LEFT JOIN legal_document_snapshots AS cancellation_refund
         ON cancellation_refund.id = contract.cancellation_refund_snapshot_id
       LEFT JOIN legal_document_snapshots AS handover_return_damage
         ON handover_return_damage.id = contract.handover_return_damage_snapshot_id
       LEFT JOIN legal_document_snapshots AS payment_payout
         ON payment_payout.id = contract.payment_payout_snapshot_id
       LEFT JOIN legal_document_snapshots AS community_safety
         ON community_safety.id = contract.community_safety_snapshot_id
       LEFT JOIN legal_document_snapshots AS reporting_moderation
         ON reporting_moderation.id = contract.reporting_moderation_review_snapshot_id
       LEFT JOIN legal_document_snapshots AS privacy
         ON privacy.id = contract.privacy_snapshot_id
       LEFT JOIN legal_document_snapshots AS imprint_withdrawal
         ON imprint_withdrawal.id = contract.imprint_withdrawal_shorttexts_snapshot_id
       WHERE contract.user_id = $1 ORDER BY contract.accepted_at`, userId),
    rows(client,
      `SELECT declaration.id, declaration.contract_id,
              declaration.declaration_type, declaration.exact_wording,
              declaration.wording_sha256, declaration.accepted_at,
              declaration.user_id, declaration.booking_id,
              declaration.document_version, declaration.locale,
              declaration.client_build, declaration.quote_id,
              declaration.quote_hash, declaration.document_references,
              declaration.created_at
       FROM platform_contract_declarations AS declaration
       JOIN platform_contracts AS contract ON contract.id = declaration.contract_id
       WHERE contract.user_id = $1 ORDER BY declaration.accepted_at`, userId),
    rows(client,
      `SELECT receipt.id, receipt.contract_id, receipt.artifact_format,
              receipt.content_html, receipt.artifact_sha256,
              receipt.generated_at, receipt.created_at
       FROM platform_contract_receipts AS receipt
       JOIN platform_contracts AS contract ON contract.id = receipt.contract_id
       WHERE contract.user_id = $1 ORDER BY receipt.generated_at`, userId),
    rows(client,
      `SELECT event.id, event.contract_id, event.event_type,
              event.artifact_format, event.artifact_sha256,
              event.artifact_reference, event.delivery_channel,
              event.occurred_at, event.metadata
       FROM platform_contract_receipt_events AS event
       JOIN platform_contracts AS contract ON contract.id = event.contract_id
       WHERE contract.user_id = $1 ORDER BY event.occurred_at`, userId),
    rows(client,
      `SELECT id, scope, platform_contract_id, booking_id, actor_name,
              electronic_channel, effect_phase, effect_status,
              eligibility_status, right_expires_at,
              submitted_at, created_at
       FROM v51_withdrawals WHERE user_id = $1 ORDER BY submitted_at`, userId),
    rows(client,
      `SELECT obligation.id, obligation.withdrawal_id, obligation.booking_id,
              obligation.refund_type, obligation.debtor_role,
              obligation.currency, obligation.status,
              obligation.amount_due_minor, obligation.maximum_minor,
              obligation.calculation_basis, obligation.created_at
       FROM v51_refund_obligations AS obligation
       JOIN v51_withdrawals AS withdrawal ON withdrawal.id = obligation.withdrawal_id
       WHERE withdrawal.user_id = $1 ORDER BY obligation.created_at`, userId),
    rows(client,
      `SELECT event.id, event.obligation_id, obligation.withdrawal_id,
              event.event_type, event.amount_due_minor,
              event.calculation_basis, event.occurred_at
       FROM v51_refund_obligation_events AS event
       JOIN v51_refund_obligations AS obligation
         ON obligation.id = event.obligation_id
       JOIN v51_withdrawals AS withdrawal
         ON withdrawal.id = obligation.withdrawal_id
       WHERE withdrawal.user_id = $1 ORDER BY event.occurred_at`, userId),
    rows(client,
      `SELECT obligation.id, obligation.booking_id, obligation.refund_type,
              obligation.debtor_role, obligation.currency, obligation.status,
              obligation.amount_due_minor, obligation.maximum_minor,
              obligation.calculation_basis, obligation.created_at
       FROM v51_cancellation_refund_obligations AS obligation
       JOIN bookings AS booking ON booking.id = obligation.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY obligation.created_at`, userId),
    rows(client,
      `SELECT receipt.id, receipt.withdrawal_id, receipt.artifact_format,
              receipt.content_html, receipt.artifact_sha256,
              receipt.generated_at, receipt.created_at
       FROM v51_withdrawal_receipts AS receipt
       JOIN v51_withdrawals AS withdrawal ON withdrawal.id = receipt.withdrawal_id
       WHERE withdrawal.user_id = $1 ORDER BY receipt.generated_at`, userId),
    rows(client,
      `SELECT event.id, event.withdrawal_id, event.event_type,
              event.artifact_sha256, event.delivery_channel,
              event.occurred_at, event.metadata
       FROM v51_withdrawal_receipt_events AS event
       JOIN v51_withdrawals AS withdrawal ON withdrawal.id = event.withdrawal_id
       WHERE withdrawal.user_id = $1 ORDER BY event.occurred_at`, userId),
    rows(client,
      `SELECT id, booking_id, item_id, archived_for, created_at,
              last_message_at, updated_at
       FROM message_threads
       WHERE user1_id = $1 OR user2_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT message.id, message.thread_id,
              (message.sender_id = $1) AS sent_by_me,
              message.sender_type, message.body, message.attachments,
              message.created_at
       FROM messages AS message
       JOIN message_threads AS thread ON thread.id = message.thread_id
       WHERE thread.user1_id = $1 OR thread.user2_id = $1
       ORDER BY message.created_at`, userId),
    rows(client,
      `SELECT id, purpose, visibility, listing_id, thread_id, mime_type,
              byte_size, image_width, image_height, created_at
       FROM uploads WHERE owner_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT evidence.id, evidence.booking_id, evidence.segment,
              evidence.evidence_kind, evidence.actor_role,
              evidence.upload_id, evidence.message_id, evidence.source,
              evidence.created_at
       FROM booking_condition_evidence AS evidence
       JOIN bookings AS booking ON booking.id = evidence.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY evidence.created_at`, userId),
    rows(client,
      `SELECT confirmation.id, confirmation.booking_id,
              confirmation.segment, confirmation.verifier_role,
              confirmation.decision, confirmation.presenter_photo_count,
              confirmation.deviation_photo_count, confirmation.created_at
       FROM booking_condition_confirmations AS confirmation
       JOIN bookings AS booking ON booking.id = confirmation.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY confirmation.created_at`, userId),
    rows(client,
      `SELECT in_app_enabled, email_enabled, push_enabled,
              message_push_enabled, booking_push_enabled, locale, updated_at
       FROM notification_preferences WHERE user_id = $1`, userId),
    rows(client,
      `SELECT id, category, kind, priority, title, body, entity_type,
              entity_id, booking_id, thread_id, read_at, archived_at, created_at
       FROM notifications WHERE user_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT id, booking_id, listing_id,
              CASE WHEN reviewer_id = $1 THEN 'submitted' ELSE 'received' END AS relationship,
              rating, body, direction, criteria, moderation_status,
              created_at, updated_at
       FROM reviews WHERE reviewer_id = $1 OR reviewee_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT id, target_type, target_id, reason_code, details, status,
              priority, reporter_reference, created_at, updated_at, closed_at
       FROM reports WHERE reporter_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT id, blocked_id, reason_code, created_at, unblocked_at
       FROM user_blocks WHERE blocker_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT payment.id, payment.booking_id, payment.status,
              payment.amount_minor, payment.currency, payment.rental_subtotal_minor,
              payment.platform_fee_minor, payment.owner_payout_minor,
              payment.security_deposit_minor, payment.captured_minor,
              payment.refunded_minor, payment.transferred_minor,
              payment.created_at, payment.updated_at
       FROM payments AS payment
       JOIN bookings AS booking ON booking.id = payment.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY payment.created_at`, userId),
    rows(client,
      `SELECT refund.id, payment.booking_id, refund.status,
              refund.amount_minor, refund.currency, refund.created_at,
              refund.updated_at
       FROM refunds AS refund
       JOIN payments AS payment ON payment.id = refund.payment_id
       JOIN bookings AS booking ON booking.id = payment.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY refund.created_at`, userId),
    rows(client,
      `SELECT id, booking_id, status, amount_minor, currency, available_at,
              paid_at, created_at, updated_at
       FROM payouts WHERE payee_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT id, booking_id, document_type, document_number, currency,
              amount_minor, private_rent_minor, sit_fee_minor,
              owner_payout_minor, rent_refund_minor, sit_fee_refund_minor,
              supplier_role, debtor_role, tax_treatment, test_mode,
              snapshot, content_html, artifact_sha256, issued_at, created_at
       FROM financial_documents
       WHERE audience_user_id = $1 ORDER BY issued_at`, userId),
    rows(client,
      `SELECT event.id, event.document_id, event.event_type,
              event.artifact_sha256, event.occurred_at, event.metadata
       FROM financial_document_events AS event
       JOIN financial_documents AS document ON document.id = event.document_id
       WHERE document.audience_user_id = $1 ORDER BY event.occurred_at`, userId),
    rows(client,
      `SELECT id, booking_id, status, maximum_amount_minor,
              charged_amount_minor, currency, consent_version, consented_at,
              expires_at, created_at, updated_at
       FROM deposit_mandates WHERE renter_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT charge.id, charge.booking_id, charge.status,
              charge.amount_minor, charge.currency, charge.succeeded_at,
              charge.created_at, charge.updated_at
       FROM deposit_charges AS charge
       JOIN bookings AS booking ON booking.id = charge.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY charge.created_at`, userId),
    rows(client,
      `SELECT dispute.id, dispute.booking_id,
              (dispute.opened_by = $1) AS opened_by_me,
              dispute.status, dispute.reason_code, dispute.summary,
              dispute.created_at, dispute.updated_at, dispute.resolved_at
       FROM disputes AS dispute
       JOIN bookings AS booking ON booking.id = dispute.booking_id
       WHERE dispute.opened_by = $1 OR booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY dispute.created_at`, userId),
    rows(client,
      `SELECT action, resource_type, resource_id, request_id, created_at
       FROM audit_log WHERE actor_id = $1 ORDER BY created_at`, userId),
  ]);

  return {
    account,
    authentication: { sessions, identities, pushDevices },
    marketplace: {
      listings,
      bookings,
      bookingQuotes,
      platformContracts,
      platformContractDeclarations,
      platformContractReceipts,
      platformContractReceiptEvents,
      withdrawals,
      withdrawalReceipts,
      withdrawalReceiptEvents,
    },
    communication: {
      messageThreads,
      messages,
      bookingConditionEvidence,
      bookingConditionConfirmations,
    },
    uploadedFiles: uploads,
    notifications: {
      preferences: notificationPreferences[0] ?? null,
      history: notifications,
    },
    trustAndSafety: { reviews, reports, blocks, disputes },
    financialActivity: {
      payments,
      refunds,
      withdrawalRefundObligations,
      withdrawalRefundObligationEvents,
      cancellationRefundObligations,
      payouts,
      financialDocuments,
      financialDocumentEvents,
      depositMandates,
      depositCharges,
    },
    auditEvents,
  };
}
