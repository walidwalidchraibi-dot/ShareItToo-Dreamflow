async function rows(client, sql, userId) {
  const result = await client.query(sql, [userId]);
  return result.rows;
}

export async function buildAccountExport(client, userId) {
  const accountResult = await client.query(
    `SELECT id, email, profile, role, account_status, phone_e164,
            email_verified_at, phone_verified_at, terms_accepted_at,
            privacy_accepted_at, minimum_age_confirmed_at,
            private_use_confirmed_at, private_marketplace_review_status,
            created_at, updated_at, password_changed_at
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
    bookingGroups,
    bookingGroupPositions,
    bookingGroupQuotes,
    bookingGroupQuotePositions,
    bookingGroupStateEvents,
    bookingGroupCommands,
    bookingGroupPositionBindings,
    bookingGroupAppointments,
    bookingGroupAppointmentCommands,
    rentalCarts,
    rentalCartProjects,
    rentalCartItems,
    platformContracts,
    platformContractDeclarations,
    platformContractReceipts,
    platformContractReceiptEvents,
    withdrawals,
    withdrawalRefundObligations,
    withdrawalRefundObligationEvents,
    cancellationRefundObligations,
    actualLossCases,
    actualLossStatements,
    actualLossResolutions,
    actualLossRefundResolutionEvents,
    actualLossReceipts,
    actualLossReceiptEvents,
    withdrawalReceipts,
    withdrawalReceiptEvents,
    messageThreads,
    messages,
    uploads,
    bookingConditionEvidence,
    bookingConditionConfirmations,
    v52ConditionEvidenceBindings,
    v52ConditionConfirmationBindings,
    v52ConfirmationChallengeBindings,
    v52ConfirmationVerificationEvents,
    v52ReturnCases,
    v52ReturnCaseEvidence,
    v52ReturnCaseEvents,
    notificationPreferences,
    notifications,
    reviews,
    reports,
    privateMarketplaceReviewEvents,
    moderationDecisions,
    moderationReviewRequests,
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
              moderation_reason_code, private_status_confirmed_at,
              private_pilot_region_code, created_at, updated_at
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
      `SELECT id,
              CASE WHEN owner_id = $1 THEN 'owner' ELSE 'renter' END AS my_role,
              marketplace_context, country_code, currency,
              rental_start_date, rental_end_date, rental_timezone,
              starts_at, ends_at, handover_location_key,
              handover_policy_version, legal_document_set_version,
              cancellation_policy_version, payment_configuration_key,
              compatibility_hash, created_at
         FROM booking_groups
        WHERE owner_id = $1 OR renter_id = $1
        ORDER BY created_at`, userId),
    rows(client,
      `SELECT position.id, position.booking_group_id, position.listing_id,
              position.booking_id, position.quote_id, position.quote_hash,
              position.currency, position.rental_subtotal_minor,
              position.platform_fee_minor, position.total_minor,
              position.owner_payout_minor, position.security_deposit_minor,
              position.sort_order, position.created_at
         FROM booking_group_positions AS position
         JOIN booking_groups AS booking_group
           ON booking_group.id = position.booking_group_id
        WHERE booking_group.owner_id = $1 OR booking_group.renter_id = $1
        ORDER BY position.booking_group_id, position.sort_order`, userId),
    rows(client,
      `SELECT quote.id, quote.booking_group_id, quote.quote_revision,
              quote.predecessor_quote_id, quote.proposal_kind,
              (quote.proposed_by_id = $1) AS proposed_by_me,
              quote.proposed_by_role, quote.item_count, quote.currency,
              quote.rental_subtotal_minor, quote.platform_fee_minor,
              quote.total_minor, quote.owner_payout_minor,
              quote.security_deposit_minor, quote.quote_hash,
              quote.issued_at, quote.expires_at
         FROM booking_group_quotes AS quote
         JOIN booking_groups AS booking_group ON booking_group.id = quote.booking_group_id
        WHERE booking_group.owner_id = $1 OR booking_group.renter_id = $1
        ORDER BY quote.booking_group_id, quote.quote_revision`, userId),
    rows(client,
      `SELECT position.id, position.group_quote_id,
              position.booking_group_id, position.group_position_id,
              position.listing_id, position.booking_quote_id,
              position.booking_quote_hash, position.currency,
              position.rental_subtotal_minor, position.platform_fee_minor,
              position.total_minor, position.owner_payout_minor,
              position.security_deposit_minor, position.sort_order,
              position.created_at
         FROM booking_group_quote_positions AS position
         JOIN booking_groups AS booking_group
           ON booking_group.id = position.booking_group_id
        WHERE booking_group.owner_id = $1 OR booking_group.renter_id = $1
        ORDER BY position.booking_group_id, position.group_quote_id, position.sort_order`, userId),
    rows(client,
      `SELECT event.id, event.booking_group_id, event.event_sequence,
              (event.actor_id = $1) AS acted_by_me,
              event.actor_group_role, event.event_type,
              event.from_state, event.to_state, event.group_quote_id,
              event.group_quote_hash, event.metadata, event.created_at
         FROM booking_group_state_events AS event
         JOIN booking_groups AS booking_group
           ON booking_group.id = event.booking_group_id
        WHERE booking_group.owner_id = $1 OR booking_group.renter_id = $1
        ORDER BY event.booking_group_id, event.event_sequence`, userId),
    rows(client,
      `SELECT command.idempotency_key, command.booking_group_id,
              (command.actor_id = $1) AS acted_by_me,
              command.command_type, command.request_hash,
              command.response_payload, command.created_at, command.completed_at
         FROM booking_group_commands AS command
         JOIN booking_groups AS booking_group
           ON booking_group.id = command.booking_group_id
        WHERE booking_group.owner_id = $1 OR booking_group.renter_id = $1
        ORDER BY command.created_at`, userId),
    rows(client,
      `SELECT binding.id, binding.booking_group_id, binding.group_quote_id,
              binding.group_quote_hash, binding.group_quote_position_id,
              binding.group_position_id, binding.listing_id, binding.booking_id,
              binding.platform_contract_id, binding.booking_quote_id,
              binding.booking_quote_hash,
              (binding.bound_by_id = $1) AS bound_by_me, binding.created_at
         FROM booking_group_position_booking_bindings AS binding
         JOIN booking_groups AS booking_group
           ON booking_group.id = binding.booking_group_id
        WHERE booking_group.owner_id = $1 OR booking_group.renter_id = $1
        ORDER BY binding.created_at`, userId),
    rows(client,
      `SELECT appointment.id, appointment.booking_group_id,
              appointment.group_quote_id, appointment.group_quote_hash,
              appointment.appointment_type, appointment.scheduled_at,
              appointment.rental_timezone, appointment.handover_location_key,
              appointment.evidence_policy, appointment.chat_policy,
              appointment.timer_policy, appointment.address_policy,
              (appointment.created_by_id = $1) AS created_by_me,
              appointment.created_at
         FROM booking_group_appointments AS appointment
         JOIN booking_groups AS booking_group
           ON booking_group.id = appointment.booking_group_id
        WHERE booking_group.owner_id = $1 OR booking_group.renter_id = $1
        ORDER BY appointment.booking_group_id, appointment.scheduled_at`, userId),
    rows(client,
      `SELECT command.idempotency_key, command.booking_group_id,
              (command.actor_id = $1) AS acted_by_me,
              command.command_type, command.request_hash,
              command.response_payload, command.created_at, command.completed_at
         FROM booking_group_appointment_commands AS command
         JOIN booking_groups AS booking_group
           ON booking_group.id = command.booking_group_id
        WHERE booking_group.owner_id = $1 OR booking_group.renter_id = $1
        ORDER BY command.created_at`, userId),
    rows(client,
      `SELECT id, schema_version, revision, created_at, updated_at
         FROM rental_carts WHERE user_id = $1 ORDER BY created_at`, userId),
    rows(client,
      `SELECT project.id, project.client_project_id, project.title,
              project.answers, project.sort_order,
              project.created_at, project.updated_at
         FROM rental_cart_projects AS project
         JOIN rental_carts AS cart ON cart.id = project.cart_id
        WHERE cart.user_id = $1
        ORDER BY project.sort_order, project.created_at`, userId),
    rows(client,
      `SELECT item.id, item.client_item_id, item.listing_id,
              project.client_project_id,
              item.rental_start_date, item.rental_end_date,
              item.quote_id, item.quote_hash, item.quote_payload,
              item.quote_status, item.quote_error_code,
              item.quote_rechecked_at, item.sort_order,
              item.created_at, item.updated_at
         FROM rental_cart_items AS item
         JOIN rental_carts AS cart ON cart.id = item.cart_id
         LEFT JOIN rental_cart_projects AS project ON project.id = item.project_id
        WHERE cart.user_id = $1
        ORDER BY item.sort_order, item.created_at`, userId),
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
      `SELECT loss_case.id, loss_case.booking_id, loss_case.cause,
              loss_case.contract_version, loss_case.locale,
              loss_case.quote_id, loss_case.quote_hash,
              loss_case.rental_subtotal_minor, loss_case.platform_fee_minor,
              loss_case.currency, loss_case.opened_at, loss_case.created_at
       FROM v52_actual_loss_cases AS loss_case
       JOIN bookings AS booking ON booking.id = loss_case.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY loss_case.opened_at`, userId),
    rows(client,
      `SELECT statement.id, statement.case_id, statement.actor_role,
              statement.statement_type, statement.owner_claimed_loss_minor,
              statement.saved_expense_minor, statement.replacement_rental_minor,
              statement.proven_lower_loss_minor, statement.evidence_references,
              statement.statement_text, statement.submitted_at
       FROM v52_actual_loss_statements AS statement
       JOIN v52_actual_loss_cases AS loss_case ON loss_case.id = statement.case_id
       JOIN bookings AS booking ON booking.id = loss_case.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY statement.submitted_at`, userId),
    rows(client,
      `SELECT resolution.id, resolution.case_id,
              resolution.renter_lower_loss_accepted, resolution.reason_code,
              resolution.calculation_basis, resolution.rent_refund_minor,
              resolution.rent_retained_minor, resolution.sit_fee_refund_minor,
              resolution.sit_fee_retained_minor, resolution.resolved_at
       FROM v52_actual_loss_resolutions AS resolution
       JOIN v52_actual_loss_cases AS loss_case ON loss_case.id = resolution.case_id
       JOIN bookings AS booking ON booking.id = loss_case.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY resolution.resolved_at`, userId),
    rows(client,
      `SELECT event.id, event.resolution_id, event.refund_type,
              event.debtor_role, event.amount_due_minor,
              event.calculation_basis, event.occurred_at
       FROM v52_cancellation_refund_resolution_events AS event
       JOIN v52_actual_loss_resolutions AS resolution
         ON resolution.id = event.resolution_id
       JOIN v52_actual_loss_cases AS loss_case ON loss_case.id = resolution.case_id
       JOIN bookings AS booking ON booking.id = loss_case.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY event.occurred_at`, userId),
    rows(client,
      `SELECT receipt.id, receipt.resolution_id, receipt.artifact_format,
              receipt.content_html, receipt.artifact_sha256,
              receipt.generated_at, receipt.created_at
       FROM v52_actual_loss_receipts AS receipt
       JOIN v52_actual_loss_resolutions AS resolution
         ON resolution.id = receipt.resolution_id
       JOIN v52_actual_loss_cases AS loss_case ON loss_case.id = resolution.case_id
       JOIN bookings AS booking ON booking.id = loss_case.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY receipt.generated_at`, userId),
    rows(client,
      `SELECT event.id, event.resolution_id, event.event_type,
              event.artifact_sha256, event.occurred_at, event.metadata
       FROM v52_actual_loss_receipt_events AS event
       JOIN v52_actual_loss_resolutions AS resolution
         ON resolution.id = event.resolution_id
       JOIN v52_actual_loss_cases AS loss_case ON loss_case.id = resolution.case_id
       JOIN bookings AS booking ON booking.id = loss_case.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY event.occurred_at`, userId),
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
              byte_size, image_width, image_height, content_sha256,
              content_scan_status, created_at
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
      `SELECT binding.evidence_id, binding.booking_id,
              binding.platform_contract_id,
              binding.handover_return_damage_snapshot_id,
              binding.quote_id, binding.quote_hash, binding.contract_version,
              binding.locale, binding.segment, binding.evidence_kind,
              binding.semantic_slot, binding.actor_role,
              (binding.actor_id = $1) AS recorded_by_me,
              binding.upload_id, binding.upload_purpose,
              binding.upload_sha256, binding.source,
              binding.observed_at, binding.created_at
       FROM v52_condition_evidence_bindings AS binding
       JOIN bookings AS booking ON booking.id = binding.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY binding.created_at`, userId),
    rows(client,
      `SELECT binding.confirmation_id, binding.booking_id,
              binding.platform_contract_id,
              binding.handover_return_damage_snapshot_id,
              binding.quote_id, binding.quote_hash, binding.contract_version,
              binding.locale, binding.segment, binding.verifier_role,
              (binding.verifier_user_id = $1) AS verified_by_me,
              binding.decision, binding.presenter_evidence_set_sha256,
              binding.presenter_photo_count, binding.deviation_photo_count,
              binding.confirmed_at, binding.created_at
       FROM v52_condition_confirmation_bindings AS binding
       JOIN bookings AS booking ON booking.id = binding.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY binding.confirmed_at`, userId),
    rows(client,
      `SELECT binding.challenge_id, binding.booking_id,
              binding.platform_contract_id,
              binding.handover_return_damage_snapshot_id,
              binding.quote_id, binding.quote_hash, binding.contract_version,
              binding.locale, binding.segment, binding.presenter_role,
              (binding.presenter_user_id = $1) AS presented_by_me,
              binding.presenter_evidence_set_sha256,
              binding.issued_at, binding.created_at
       FROM v52_confirmation_challenge_bindings AS binding
       JOIN bookings AS booking ON booking.id = binding.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY binding.issued_at`, userId),
    rows(client,
      `SELECT event.id, event.challenge_id, event.confirmation_id,
              event.booking_id,
              (event.verifier_user_id = $1) AS verified_by_me,
              event.verifier_role, event.presenter_evidence_set_sha256,
              event.verification_method, event.verified_at, event.created_at
       FROM v52_confirmation_verification_events AS event
       JOIN bookings AS booking ON booking.id = event.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY event.verified_at`, userId),
    rows(client,
      `SELECT return_case.id, return_case.booking_case_id,
              return_case.report_id, return_case.booking_id,
              return_case.platform_contract_id,
              return_case.handover_return_damage_snapshot_id,
              return_case.quote_id, return_case.quote_hash,
              return_case.contract_version, return_case.locale,
              (return_case.opened_by = $1) AS opened_by_me,
              return_case.opened_by_role, return_case.reason_code,
              return_case.reason_details, return_case.t0, return_case.t1,
              return_case.report_deadline, return_case.response_due_at,
              return_case.next_status_update_due_at,
              return_case.authorized_booking_minor,
              return_case.contested_authorized_minor,
              return_case.undisputed_releasable_minor,
              return_case.additional_charge_minor, return_case.created_at
       FROM v52_return_cases AS return_case
       JOIN bookings AS booking ON booking.id = return_case.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY return_case.t1`, userId),
    rows(client,
      `SELECT evidence.return_case_id, evidence.upload_id,
              evidence.upload_purpose, evidence.upload_sha256,
              evidence.created_at
       FROM v52_return_case_evidence AS evidence
       JOIN v52_return_cases AS return_case ON return_case.id = evidence.return_case_id
       JOIN bookings AS booking ON booking.id = return_case.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY evidence.created_at`, userId),
    rows(client,
      `SELECT event.id, event.return_case_id,
              (event.actor_id = $1) AS acted_by_me,
              event.actor_role, event.event_type, event.occurred_at,
              event.metadata, event.created_at
       FROM v52_return_case_events AS event
       JOIN v52_return_cases AS return_case ON return_case.id = event.return_case_id
       JOIN bookings AS booking ON booking.id = return_case.booking_id
       WHERE booking.owner_id = $1 OR booking.renter_id = $1
       ORDER BY event.occurred_at`, userId),
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
      `SELECT id, from_status, to_status, reason_code, created_at
       FROM private_marketplace_review_events
       WHERE user_id = $1 ORDER BY created_at, id`, userId),
    rows(client,
      `SELECT id, report_id, target_type, target_id, measure_type,
              measure_state, facts, basis, reasoning, detection_method,
              automated_means, review_available, review_deadline_at, created_at
       FROM moderation_decisions
       WHERE recipient_user_id = $1 ORDER BY created_at, id`, userId),
    rows(client,
      `SELECT request.id, request.decision_id, request.reason, request.status,
              request.resolution, request.submitted_at, request.updated_at,
              request.resolved_at
       FROM moderation_review_requests AS request
       WHERE request.requester_id = $1 ORDER BY request.submitted_at, request.id`, userId),
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
      bookingGroups: {
        groups: bookingGroups,
        positions: bookingGroupPositions,
        quotes: bookingGroupQuotes,
        quotePositions: bookingGroupQuotePositions,
        stateEvents: bookingGroupStateEvents,
        commands: bookingGroupCommands,
        itemBookingBindings: bookingGroupPositionBindings,
        sharedAppointments: bookingGroupAppointments,
        appointmentCommands: bookingGroupAppointmentCommands,
        itemEvidenceRemainsInV52BookingRecords: true,
      },
      rentalCart: {
        cart: rentalCarts[0] ?? null,
        projects: rentalCartProjects,
        items: rentalCartItems,
        reservationCreated: false,
      },
      platformContracts,
      platformContractDeclarations,
      platformContractReceipts,
      platformContractReceiptEvents,
      withdrawals,
      withdrawalReceipts,
      withdrawalReceiptEvents,
      actualLossCases,
      actualLossStatements,
      actualLossResolutions,
      actualLossReceipts,
      actualLossReceiptEvents,
    },
    communication: {
      messageThreads,
      messages,
      bookingConditionEvidence,
      bookingConditionConfirmations,
      v52ConditionEvidenceBindings,
      v52ConditionConfirmationBindings,
      v52ConfirmationChallengeBindings,
      v52ConfirmationVerificationEvents,
      v52ReturnCases,
      v52ReturnCaseEvidence,
      v52ReturnCaseEvents,
    },
    uploadedFiles: uploads,
    notifications: {
      preferences: notificationPreferences[0] ?? null,
      history: notifications,
    },
    trustAndSafety: {
      reviews,
      reports,
      privateMarketplaceReviewEvents,
      moderationDecisions,
      moderationReviewRequests,
      blocks,
      disputes,
    },
    financialActivity: {
      payments,
      refunds,
      withdrawalRefundObligations,
      withdrawalRefundObligationEvents,
      cancellationRefundObligations,
      actualLossRefundResolutionEvents,
      payouts,
      financialDocuments,
      financialDocumentEvents,
      depositMandates,
      depositCharges,
    },
    auditEvents,
  };
}
