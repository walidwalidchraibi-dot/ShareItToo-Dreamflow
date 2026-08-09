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
    messageThreads,
    messages,
    uploads,
    notificationPreferences,
    notifications,
    reviews,
    reports,
    blocks,
    payments,
    refunds,
    payouts,
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
      `SELECT provider, provider_subject, email_at_link, email_verified,
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
    marketplace: { listings, bookings },
    communication: { messageThreads, messages },
    uploadedFiles: uploads,
    notifications: {
      preferences: notificationPreferences[0] ?? null,
      history: notifications,
    },
    trustAndSafety: { reviews, reports, blocks, disputes },
    financialActivity: {
      payments,
      refunds,
      payouts,
      depositMandates,
      depositCharges,
    },
    auditEvents,
  };
}
