const formatterCache = new Map();

function instant(value, code) {
  const parsed = value instanceof Date ? new Date(value) : new Date(value);
  if (!Number.isFinite(parsed.getTime())) throw new Error(code);
  return parsed;
}

export function returnPolicyTimeZone(value = 'Europe/Berlin') {
  const timezone = typeof value === 'string' ? value.trim() : '';
  if (!timezone || timezone.length > 120) {
    throw new Error('invalid_return_policy_timezone');
  }
  try {
    new Intl.DateTimeFormat('en-GB', { timeZone: timezone }).format(new Date(0));
  } catch {
    throw new Error('invalid_return_policy_timezone');
  }
  return timezone;
}

function formatter(timezone) {
  let value = formatterCache.get(timezone);
  if (value) return value;
  value = new Intl.DateTimeFormat('en-GB-u-ca-iso8601-nu-latn', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    fractionalSecondDigits: 3,
    hourCycle: 'h23',
  });
  formatterCache.set(timezone, value);
  return value;
}

function localParts(value, timezone) {
  const parts = Object.fromEntries(
    formatter(timezone).formatToParts(value).map((part) => [part.type, part.value]),
  );
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
    millisecond: Number(parts.fractionalSecond ?? 0),
  };
}

function localStamp(parts) {
  return Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
    parts.millisecond,
  );
}

function resolveLocalInstant(parts, timezone) {
  const target = localStamp(parts);
  let candidate = target;
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const delta = target - localStamp(localParts(new Date(candidate), timezone));
    if (delta === 0) break;
    candidate += delta;
  }

  // An autumn clock change can map the same wall-clock time to two instants.
  // Select the earlier one deterministically. For a skipped spring time, use
  // the first representable wall-clock value after the gap (Temporal's
  // compatible behavior and PostgreSQL's AT TIME ZONE behavior).
  const exact = [];
  const later = [];
  for (let offsetHours = -6; offsetHours <= 6; offsetHours += 1) {
    const value = candidate + offsetHours * 60 * 60 * 1000;
    const observed = localStamp(localParts(new Date(value), timezone));
    if (observed === target) exact.push(value);
    if (observed > target) later.push({ value, observed });
  }
  if (exact.length) return new Date(Math.min(...exact));
  later.sort((left, right) => left.observed - right.observed || left.value - right.value);
  if (later.length) return new Date(later[0].value);
  throw new Error('unresolvable_return_policy_calendar_time');
}

export function addReturnPolicyCalendarDays(value, days, timezone = 'Europe/Berlin') {
  const source = instant(value, 'invalid_return_policy_instant');
  if (!Number.isSafeInteger(days) || days < 0 || days > 3660) {
    throw new Error('invalid_return_policy_calendar_days');
  }
  const zone = returnPolicyTimeZone(timezone);
  const sourceParts = localParts(source, zone);
  const shiftedDate = new Date(Date.UTC(
    sourceParts.year,
    sourceParts.month - 1,
    sourceParts.day + days,
  ));
  return resolveLocalInstant({
    ...sourceParts,
    year: shiftedDate.getUTCFullYear(),
    month: shiftedDate.getUTCMonth() + 1,
    day: shiftedDate.getUTCDate(),
  }, zone);
}
