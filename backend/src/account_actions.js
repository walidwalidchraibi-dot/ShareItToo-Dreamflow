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

function pageShell({ title, content }) {
  return `<!doctype html><html lang="de"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer"><title>${escapeHtml(title)} · ShareItToo</title>
<style>body{margin:0;background:#edf2fb;color:#172033;font-family:Arial,sans-serif}.wrap{max-width:560px;margin:8vh auto;padding:20px}.card{background:#fff;border-radius:22px;padding:32px;box-shadow:0 16px 42px rgba(24,45,90,.12)}.brand{color:#2156d9;font-size:25px;font-weight:800;margin-bottom:24px}h1{font-size:25px;margin:0 0 14px}p{line-height:1.55;color:#4d596f}.button,button{display:inline-block;border:0;border-radius:12px;background:#2156d9;color:#fff;text-decoration:none;font-weight:700;padding:14px 20px;cursor:pointer}label{display:block;font-weight:700;margin:15px 0 7px}input{box-sizing:border-box;width:100%;border:1px solid #c9d3e6;border-radius:11px;padding:13px;font-size:16px}.hint{font-size:13px}.error{color:#b42318;font-weight:700}</style>
</head><body><main class="wrap"><section class="card"><div class="brand">ShareItToo</div>${content}</section></main></body></html>`;
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
