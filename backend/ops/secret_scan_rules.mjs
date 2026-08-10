const directRules = [
  ['private_key', /-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----/u],
  ['aws_access_key', /\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/u],
  ['github_token', /\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})\b/u],
  ['openai_key', /\bsk-(?:proj-)?[A-Za-z0-9_-]{32,}\b/u],
  ['stripe_live_key', /\b(?:sk|rk)_live_[A-Za-z0-9]{20,}\b/u],
  ['google_api_key', /\bAIza[0-9A-Za-z_-]{35}\b/u],
  ['slack_token', /\bxox[baprs]-[0-9A-Za-z-]{20,}\b/u],
  ['static_password_assignment', /\b(?:const|let|var)\s+[\w$]*password[\w$]*\s*=\s*(['"])[^'"\r\n]{8,}\1/iu],
  ['static_password_property', /\b(?:password|currentPassword|newPassword)\s*:\s*(['"])[^'"\r\n]{8,}\1/iu],
];

const templateRules = [
  [
    'static_password_template_assignment',
    /\b(?:const|let|var)\s+[\w$]*password[\w$]*\s*=\s*`([^`\r\n]*)`/giu,
  ],
  [
    'static_password_template_property',
    /\b(?:password|currentPassword|newPassword)\s*:\s*`([^`\r\n]*)`/giu,
  ],
];

function removeIntentionalPublicDemoCredential(text, file) {
  if (file !== 'lib/services/auth_service.dart') return text;
  return text.replace(
    /\bstatic\s+const\s+demoPassword\s*=\s*(['"])[^'"\r\n]*\1/giu,
    'static const demoPassword = ""',
  );
}

function staticTemplateCharacterCount(templateBody) {
  return templateBody.replace(/\$\{[^}]*\}/gu, '').length;
}

export function detectHighConfidenceSecretRules(text, file) {
  const inspectedText = removeIntentionalPublicDemoCredential(text, file);
  const findings = new Set();

  for (const [rule, pattern] of directRules) {
    if (pattern.test(inspectedText)) findings.add(rule);
  }

  for (const [rule, pattern] of templateRules) {
    pattern.lastIndex = 0;
    for (const match of inspectedText.matchAll(pattern)) {
      if (staticTemplateCharacterCount(match[1]) >= 8) findings.add(rule);
    }
  }

  return [...findings];
}
