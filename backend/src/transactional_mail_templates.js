const TEMPLATE_DEFINITIONS = Object.freeze({
  booking_requested: {
    subject: ({ itemTitle }) => `Neue Buchungsanfrage · ${itemTitle}`,
    title: 'Neue Buchungsanfrage',
    intro: ({ greeting, itemTitle }) =>
      `${greeting} für „${itemTitle}“ ist eine neue Buchungsanfrage eingegangen.`,
    actionLabel: 'Anfrage ansehen',
    notice: 'Prüfe Zeitraum, Übergabe und Preis, bevor du die Anfrage annimmst.',
  },
  booking_confirmed: {
    subject: ({ itemTitle }) => `Buchung bestätigt · ${itemTitle}`,
    title: 'Buchung bestätigt',
    intro: ({ greeting, itemTitle }) =>
      `${greeting} deine Buchung für „${itemTitle}“ wurde bestätigt.`,
    actionLabel: 'Buchung öffnen',
    notice: 'Nutze für Absprachen ausschließlich den Buchungs-Chat in ShareItToo.',
  },
  payment_confirmed: {
    subject: ({ itemTitle }) => `Zahlung bestätigt · ${itemTitle}`,
    title: 'Zahlung bestätigt',
    intro: ({ greeting, itemTitle }) =>
      `${greeting} die Zahlung für „${itemTitle}“ wurde erfolgreich bestätigt.`,
    actionLabel: 'Zahlungsübersicht öffnen',
    notice: 'Kartendaten werden niemals per E-Mail angefordert oder angezeigt.',
    requiresAmount: true,
  },
  booking_cancelled: {
    subject: ({ itemTitle }) => `Buchung storniert · ${itemTitle}`,
    title: 'Buchung storniert',
    intro: ({ greeting, itemTitle }) =>
      `${greeting} die Buchung für „${itemTitle}“ wurde storniert.`,
    actionLabel: 'Stornierung ansehen',
    notice: 'Eine mögliche Rückerstattung wird ausschließlich in der Buchungsübersicht ausgewiesen.',
  },
  handover_reminder: {
    subject: ({ itemTitle }) => `Erinnerung an die Übergabe · ${itemTitle}`,
    title: 'Übergabe steht bevor',
    intro: ({ greeting, itemTitle }) =>
      `${greeting} die Übergabe für „${itemTitle}“ steht bevor.`,
    actionLabel: 'Übergabe öffnen',
    notice: 'Bestätige den Zustand erst vor Ort und teile keine Zahlungsdaten im Chat.',
    requiresEventLabel: true,
  },
  return_reminder: {
    subject: ({ itemTitle }) => `Erinnerung an die Rückgabe · ${itemTitle}`,
    title: 'Rückgabe steht bevor',
    intro: ({ greeting, itemTitle }) =>
      `${greeting} die Rückgabe für „${itemTitle}“ steht bevor.`,
    actionLabel: 'Rückgabe öffnen',
    notice: 'Dokumentiere Abweichungen vor dem Abschluss direkt in der Buchung.',
    requiresEventLabel: true,
  },
  payout_sent: {
    subject: ({ itemTitle }) => `Auszahlung veranlasst · ${itemTitle}`,
    title: 'Auszahlung veranlasst',
    intro: ({ greeting, itemTitle }) =>
      `${greeting} die Auszahlung für „${itemTitle}“ wurde veranlasst.`,
    actionLabel: 'Auszahlung ansehen',
    notice: 'Je nach Bank kann die Gutschrift einige Werktage benötigen.',
    requiresAmount: true,
  },
});

export const transactionalEmailKinds = Object.freeze(
  Object.keys(TEMPLATE_DEFINITIONS),
);

function requiredText(value, field, maxLength = 240) {
  if (typeof value !== 'string') throw new TypeError(`${field}_required`);
  const normalized = value.trim();
  if (
    !normalized ||
    normalized.length > maxLength ||
    /[\r\n\u2028\u2029]/u.test(normalized)
  ) {
    throw new TypeError(`${field}_invalid`);
  }
  return normalized;
}

function optionalText(value, field, maxLength = 240) {
  if (value === undefined || value === null || value === '') return '';
  return requiredText(value, field, maxLength);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function safeActionUrl(value) {
  const raw = requiredText(value, 'action_url', 2_000);
  let parsed;
  try {
    parsed = new URL(raw);
  } catch {
    throw new TypeError('action_url_invalid');
  }
  if (!['https:', 'http:'].includes(parsed.protocol)) {
    throw new TypeError('action_url_invalid');
  }
  return parsed.toString();
}

function formatAmount(amount, currency) {
  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount < 0) {
    throw new TypeError('amount_invalid');
  }
  const normalizedCurrency = requiredText(currency ?? 'EUR', 'currency', 3)
    .toUpperCase();
  if (!/^[A-Z]{3}$/.test(normalizedCurrency)) {
    throw new TypeError('currency_invalid');
  }
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: normalizedCurrency,
  }).format(amount);
}

function renderHtml({ title, intro, actionLabel, actionUrl, details, notice }) {
  const rows = details.map(({ label, value }) => `
<tr><td style="padding:7px 12px 7px 0;color:#5d6980;vertical-align:top">${escapeHtml(label)}</td><td style="padding:7px 0;font-weight:700;vertical-align:top">${escapeHtml(value)}</td></tr>`).join('');
  return `<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>${escapeHtml(title)}</title></head>
<body style="margin:0;background:#f3f6fb;font-family:Arial,sans-serif;color:#172033">
<div style="max-width:600px;margin:0 auto;padding:32px 18px">
<div style="background:#ffffff;border-radius:20px;padding:32px;box-shadow:0 10px 30px rgba(20,35,70,.08)">
<div style="font-size:25px;font-weight:800;color:#2156d9;margin-bottom:24px">ShareItToo</div>
<h1 style="font-size:24px;margin:0 0 14px">${escapeHtml(title)}</h1>
<p style="font-size:16px;line-height:1.55;margin:0 0 20px">${escapeHtml(intro)}</p>
<table role="presentation" style="width:100%;border-collapse:collapse;margin:0 0 24px">${rows}
</table>
<p style="margin:0 0 24px"><a href="${escapeHtml(actionUrl)}" style="display:inline-block;background:#2156d9;color:#fff;text-decoration:none;font-weight:700;padding:14px 22px;border-radius:12px">${escapeHtml(actionLabel)}</a></p>
<p style="font-size:13px;line-height:1.5;color:#5d6980">${escapeHtml(notice)}</p>
<p style="font-size:13px;line-height:1.5;color:#5d6980;word-break:break-all">Falls der Button nicht funktioniert:<br>${escapeHtml(actionUrl)}</p>
</div></div></body></html>`;
}

export function buildTransactionalEmail({
  kind,
  displayName,
  bookingReference,
  itemTitle,
  amount,
  currency = 'EUR',
  eventLabel,
  actionUrl,
}) {
  const definition = TEMPLATE_DEFINITIONS[kind];
  if (!definition) throw new TypeError('transactional_email_kind_invalid');

  const name = optionalText(displayName, 'display_name', 120);
  const reference = requiredText(bookingReference, 'booking_reference', 120);
  const item = requiredText(itemTitle, 'item_title', 240);
  const schedule = optionalText(eventLabel, 'event_label', 240);
  const url = safeActionUrl(actionUrl);
  if (definition.requiresEventLabel && !schedule) {
    throw new TypeError('event_label_required');
  }

  const greeting = name ? `Hallo ${name},` : 'Hallo,';
  const formattedAmount = definition.requiresAmount
    ? formatAmount(amount, currency)
    : '';
  const variables = { greeting, itemTitle: item };
  const details = [
    { label: 'Buchungsnummer', value: reference },
    { label: 'Artikel', value: item },
    ...(schedule ? [{ label: 'Zeitpunkt', value: schedule }] : []),
    ...(formattedAmount ? [{ label: 'Betrag', value: formattedAmount }] : []),
  ];
  const intro = definition.intro(variables);
  const subject = definition.subject(variables);
  const textDetails = details.map(({ label, value }) => `${label}: ${value}`).join('\n');

  return Object.freeze({
    subject,
    text: `${intro}\n\n${textDetails}\n\n${definition.actionLabel}: ${url}\n\n${definition.notice}`,
    html: renderHtml({
      title: definition.title,
      intro,
      actionLabel: definition.actionLabel,
      actionUrl: url,
      details,
      notice: definition.notice,
    }),
  });
}
