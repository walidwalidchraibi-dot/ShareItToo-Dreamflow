import { config } from './config.js';
import { hashActionToken, newActionToken } from './security.js';

export async function createActionToken(client, { userId, kind, payload = {} }) {
  const token = newActionToken();
  const lifetimeMs = ['verify_email', 'change_email'].includes(kind)
    ? config.emailVerificationLifetimeHours * 60 * 60 * 1000
    : (kind === 'delete_account'
      ? config.accountDeletionLifetimeMinutes
      : config.passwordResetLifetimeMinutes) * 60 * 1000;
  const expiresAt = new Date(Date.now() + lifetimeMs);
  await client.query(
    `UPDATE auth_action_tokens
     SET consumed_at = COALESCE(consumed_at, now())
     WHERE user_id = $1 AND kind = $2 AND consumed_at IS NULL`,
    [userId, kind],
  );
  await client.query(
    `INSERT INTO auth_action_tokens (user_id, kind, token_hash, expires_at, payload)
     VALUES ($1, $2, $3, $4, $5::jsonb)`,
    [userId, kind, hashActionToken(token), expiresAt, JSON.stringify(payload)],
  );
  return token;
}

export async function lockValidActionToken(client, { token, kind }) {
  if (typeof token !== 'string' || token.length < 32 || token.length > 500) return null;
  const result = await client.query(
    `SELECT aat.id AS action_token_id, aat.user_id, aat.expires_at,
            aat.payload AS action_payload,
            u.id, u.email, u.password_hash, u.profile, u.created_at,
            u.updated_at, u.deactivated_at, u.email_verified_at, u.password_changed_at,
            u.role, u.account_status, u.terms_accepted_at, u.privacy_accepted_at,
            u.minimum_age_confirmed_at, u.phone_verified_at
     FROM auth_action_tokens aat
     JOIN users u ON u.id = aat.user_id
     WHERE aat.token_hash = $1 AND aat.kind = $2
       AND aat.consumed_at IS NULL AND aat.expires_at > now()
       AND u.deactivated_at IS NULL
     FOR UPDATE OF aat, u`,
    [hashActionToken(token), kind],
  );
  return result.rows[0] ?? null;
}

export async function consumeActionToken(client, actionTokenId) {
  await client.query(
    'UPDATE auth_action_tokens SET consumed_at = now() WHERE id = $1 AND consumed_at IS NULL',
    [actionTokenId],
  );
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function pageShell({ title, content, pageId = '', complianceStatus = '' }) {
  const pageAttribute = pageId
    ? ` data-sit-public-page="${escapeHtml(pageId)}"`
    : '';
  const statusAttribute = complianceStatus
    ? ` data-sit-compliance-status="${escapeHtml(complianceStatus)}"`
    : '';
  return `<!doctype html><html lang="de"${pageAttribute}${statusAttribute}><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer"><title>${escapeHtml(title)} · ShareItToo</title>
<style>body{margin:0;background:#edf2fb;color:#172033;font-family:Arial,sans-serif}.wrap{max-width:720px;margin:6vh auto;padding:20px}.card{background:#fff;border-radius:22px;padding:32px;box-shadow:0 16px 42px rgba(24,45,90,.12)}.brand{color:#2156d9;font-size:25px;font-weight:800;margin-bottom:24px}h1{font-size:25px;margin:0 0 14px}h2{font-size:19px;margin:28px 0 8px}p,li{line-height:1.55;color:#4d596f}.button,button{display:inline-block;border:0;border-radius:12px;background:#2156d9;color:#fff;text-decoration:none;font-weight:700;padding:14px 20px;cursor:pointer}a{color:#1748bd}label{display:block;font-weight:700;margin:15px 0 7px}input{box-sizing:border-box;width:100%;border:1px solid #c9d3e6;border-radius:11px;padding:13px;font-size:16px}.hint{font-size:13px}.error{color:#b42318;font-weight:700}.draft{border-left:4px solid #b54708;background:#fff4e5;padding:12px 14px;color:#713b12}.meta{font-size:13px;color:#667085}</style>
</head><body><main class="wrap"><section class="card"><div class="brand">ShareItToo</div>${content}</section></main></body></html>`;
}

export function publicComplianceOverview() {
  const { approved } = config.publicCompliance;
  return {
    status: approved ? 'approved' : 'draft',
    submissionReady: approved,
    pages: {
      support: approved ? 'approved' : 'draft',
      privacy: approved ? 'approved' : 'draft',
      accountDeletion: 'operational',
    },
  };
}

export function publicSupportPage() {
  const { approved, supportEmail } = config.publicCompliance;
  const status = approved ? 'approved' : 'draft';
  const content = approved
    ? `<h1>Support</h1><p>Wir helfen bei Fragen zu Konten, Inseraten, Buchungen, Zahlungen, Sicherheit und Meldungen.</p>
<h2>Kontakt</h2><p><a href="mailto:${escapeHtml(supportEmail)}">${escapeHtml(supportEmail)}</a></p>
<p>In der App findest du außerdem unter Profil → Hilfe den Hilfebereich und die geschützten Supportwege zu einer Buchung.</p>`
    : `<h1>Support</h1><p class="draft">Diese öffentliche Supportseite ist technisch vorbereitet, aber der verbindliche Supportkontakt wurde noch nicht geschäftlich freigegeben.</p>
<p>Vor einer Store-Einreichung werden Kontaktadresse, Zustellung und Verantwortlichkeit bestätigt. Bis dahin darf diese Seite nicht als freigegebene Store-URL verwendet werden.</p>`;
  return pageShell({
    title: 'Support',
    pageId: 'support',
    complianceStatus: status,
    content,
  });
}

export function publicPrivacyPage() {
  const compliance = config.publicCompliance;
  const status = compliance.approved ? 'approved' : 'draft';
  const content = compliance.approved
    ? `<h1>Datenschutz</h1><p class="meta">Stand: ${escapeHtml(compliance.effectiveDate)}</p>
<h2>Verantwortlicher</h2><p>${escapeHtml(compliance.providerName)}<br>${escapeHtml(compliance.providerAddress)}<br><a href="mailto:${escapeHtml(compliance.privacyEmail)}">${escapeHtml(compliance.privacyEmail)}</a></p>
<h2>Welche Daten verarbeitet werden</h2><p>Je nach Nutzung verarbeitet ShareItToo Konto- und Kontaktdaten, Alters- und Verifizierungsstatus, Inserats- und Mediendaten, ungefähre oder funktionsbezogene Standortdaten, Buchungs- und Kommunikationsdaten, Zahlungs- und Auszahlungsreferenzen, Geräte- und Push-Token sowie Sicherheits-, Audit- und Crashdiagnosedaten.</p>
<h2>Zwecke und Rechtsgrundlagen</h2><p>Die Verarbeitung dient der Konto- und Vertragsdurchführung, Vermittlung physischer Mietvorgänge, Kommunikation, Zahlungsabwicklung, Sicherheit, Missbrauchsabwehr, Support, gesetzlichen Nachweisen und – soweit erforderlich – deiner Einwilligung.</p>
<h2>Empfänger und Dienstleister</h2><p>Daten werden nur zweckgebunden an erforderliche Hosting-, E-Mail-, Push-, Diagnose- und Zahlungsdienstleister sowie bei rechtlicher Pflicht an zuständige Stellen übermittelt. Zahlungsdaten werden nicht vollständig bei ShareItToo gespeichert.</p>
<h2>Speicherung, Löschung und Rechte</h2><p>Personenbezogene Daten werden nur so lange gespeichert, wie es für den jeweiligen Zweck oder gesetzliche Pflichten erforderlich ist. Du kannst in der App Daten exportieren und dein Konto löschen; alternativ steht die öffentliche Kontolöschseite zur Verfügung. Dir können insbesondere Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit, Widerspruch und Beschwerde bei einer Datenschutzaufsicht zustehen.</p>
<h2>Datenschutzkontakt</h2><p>Fragen oder Anträge sendest du an <a href="mailto:${escapeHtml(compliance.privacyEmail)}">${escapeHtml(compliance.privacyEmail)}</a>.</p>`
    : `<h1>Datenschutz</h1><p class="draft">Diese öffentliche Datenschutzerklärung ist technisch vorbereitet, befindet sich aber noch in fachlicher und rechtlicher Endprüfung.</p>
<p>Verantwortlicher, Kontakt, Rechtsgrundlagen, Empfänger, Aufbewahrungsfristen und Betroffenenrechte müssen vor Veröffentlichung bestätigt werden. Bis dahin darf diese Seite nicht als freigegebene Store-URL verwendet werden.</p>`;
  return pageShell({
    title: 'Datenschutz',
    pageId: 'privacy',
    complianceStatus: status,
    content,
  });
}

export function resultPage({ success, title, message }) {
  return pageShell({
    title,
    content: `<h1>${escapeHtml(title)}</h1><p class="${success ? '' : 'error'}">${escapeHtml(message)}</p><p><a class="button" href="${escapeHtml(config.appPublicUrl)}">ShareItToo öffnen</a></p>`,
  });
}

export function passwordResetForm({ token, error = '' }) {
  return pageShell({
    title: 'Passwort zurücksetzen',
    content: `<h1>Neues Passwort festlegen</h1><p>Wähle ein neues Passwort mit mindestens zehn Zeichen, einem Buchstaben und einer Zahl.</p>
${error ? `<p class="error">${escapeHtml(error)}</p>` : ''}
<form method="post" action="${escapeHtml(config.publicBaseUrl)}/auth/password-reset/form" autocomplete="off">
<input type="hidden" name="token" value="${escapeHtml(token)}">
<label for="password">Neues Passwort</label><input id="password" name="password" type="password" minlength="10" maxlength="200" autocomplete="new-password" required>
<label for="passwordConfirm">Passwort wiederholen</label><input id="passwordConfirm" name="passwordConfirm" type="password" minlength="10" maxlength="200" autocomplete="new-password" required>
<p class="hint">Der Link kann nur einmal verwendet werden.</p><button type="submit">Passwort speichern</button></form>`,
  });
}

export function accountDeletionRequestForm({ submitted = false }) {
  return pageShell({
    title: 'ShareItToo-Konto löschen',
    pageId: 'account-deletion',
    complianceStatus: 'operational',
    content: submitted
      ? `<h1>Anfrage erhalten</h1><p>Wenn ein aktives Konto zu dieser Adresse gehört, senden wir einen einmal verwendbaren Bestätigungslink. Prüfe auch den Spam-Ordner.</p>`
      : `<h1>Konto löschen</h1><p>Du kannst die Löschung direkt in der App unter Konto → Konto löschen starten. Alternativ senden wir dir hier einen sicheren Bestätigungslink.</p>
<form method="post" action="${escapeHtml(config.publicBaseUrl)}/account-deletion/request" autocomplete="off">
<label for="email">E-Mail-Adresse</label><input id="email" name="email" type="email" maxlength="254" autocomplete="email" required>
<p class="hint">Offene Buchungen, Auszahlungen oder Streitfälle müssen zuerst abgeschlossen werden. Gesetzlich erforderliche Transaktionsnachweise werden nur pseudonymisiert aufbewahrt.</p>
<button type="submit">Löschung anfordern</button></form>`,
  });
}

export function accountDeletionConfirmForm({ token, error = '' }) {
  return pageShell({
    title: 'Kontolöschung bestätigen',
    content: `<h1>Konto endgültig löschen?</h1><p>Profil-, Kontakt-, Geräte- und Zugangsdaten werden gelöscht oder anonymisiert. Gesetzlich erforderliche Buchungs- und Zahlungsnachweise bleiben pseudonymisiert erhalten.</p>
${error ? `<p class="error">${escapeHtml(error)}</p>` : ''}
<form method="post" action="${escapeHtml(config.publicBaseUrl)}/account-deletion/confirm" autocomplete="off">
<input type="hidden" name="token" value="${escapeHtml(token)}">
<button type="submit">Konto endgültig löschen</button></form>`,
  });
}
