import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../../lib/screens/booking_detail_screen.dart', import.meta.url),
  'utf8',
);

function section(start, end) {
  const startIndex = source.indexOf(start);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.notEqual(startIndex, -1, `expected section start: ${start}`);
  assert.notEqual(endIndex, -1, `expected section end: ${end}`);
  return source.slice(startIndex, endIndex);
}

const ownerReturn = section(
  '  Future<void> _startOwnerReturnFlow()',
  '  Future<void> _startPickupFlow()',
);
const pickup = section(
  '  Future<void> _startPickupFlow()',
  '  Future<void> _downloadReceiptPdf()',
);
const pickupQr = section(
  '  Future<void> _startScanOwnerQr()',
  '  Future<void> _startScanRenterQrForReturn()',
);
const returnQr = section(
  '  Future<void> _startScanRenterQrForReturn()',
  '  Future<void> _confirmManualReturnByCode()',
);
const manualReturn = section(
  '  Future<void> _confirmManualReturnByCode()',
  '  Future<bool> _hasRequiredHandoverPhotos',
);
const manualPickup = section(
  '  Future<void> _confirmManualPickupByCode()',
  '  Future<void> _confirmCancelUpcoming()',
);

test('both steppers stop after challenge lookup when their State is gone', () => {
  for (const value of [ownerReturn, pickup]) {
    assert.match(
      value,
      /challenge = await _issueSecureChallenge\([\s\S]*?if \(challenge == null\) return;\s+\}\s+if \(!mounted\) return;\s+final ok = await ReturnHandoverStepperSheet\.push\(\s+context,/u,
    );
  }
});

test('owner return proves lifecycle after identity and transition work', () => {
  assert.match(
    ownerReturn,
    /getCurrentUser\(\);\s+if \(!mounted\) return;[\s\S]*?Diese Best\u00e4tigung ist nur f\u00fcr den Vermieter m\u00f6glich/u,
  );
  assert.match(
    ownerReturn,
    /_syncBookingLifecycleFromRequest\(requestId\);\s+\}\s+if \(!mounted\) return;[\s\S]*?AppPopup\.show\(\s+context,/u,
  );
});

test('stepper and QR pickup feedback require a current State', () => {
  assert.match(
    pickup,
    /setHandoverBanner\([\s\S]*?\);\s+if \(!mounted\) return;\s+AppPopup\.toast\(\s+context,/u,
  );
  assert.match(
    pickupQr,
    /_guardAuthenticatedRenter\(\);\s+if \(renterUserId == null \|\| !mounted\) return;/u,
  );
  assert.match(
    pickupQr,
    /addNotification\([\s\S]*?\);\s+if \(!mounted\) return;\s+AppPopup\.toast\(\s+context,/u,
  );
});

test('QR and manual return prove identity and result-feedback lifecycle', () => {
  for (const value of [returnQr, manualReturn]) {
    assert.match(
      value,
      /getCurrentUser\(\);\s+if \(!mounted\) return;[\s\S]*?Diese Best\u00e4tigung ist nur f\u00fcr den Vermieter m\u00f6glich/u,
    );
    assert.match(
      value,
      /addNotification\([\s\S]*?\);\s+if \(!mounted\) return;\s+AppPopup\.toast\(\s+context,/u,
    );
  }
  assert.match(
    manualReturn,
    /R\u00fcckgabe per Code best\u00e4tigt'[\s\S]*?\);\s+if \(!mounted\) return;\s+setState\(/u,
  );
});

test('manual pickup proves lifecycle before flow and local result state', () => {
  assert.match(
    manualPickup,
    /_guardAuthenticatedRenter\(\);\s+if \(renterUserId == null \|\| !mounted\) return;/u,
  );
  assert.match(
    manualPickup,
    /setHandoverBanner\([\s\S]*?\);\s+if \(!mounted\) return;\s+AppPopup\.toast\(\s+context,[\s\S]*?\);\s+if \(!mounted\) return;\s+setState\(/u,
  );
});

test('handover and return context fixes add no timing or lint accommodation', () => {
  for (const value of [
    ownerReturn,
    pickup,
    pickupQr,
    returnQr,
    manualReturn,
    manualPickup,
  ]) {
    assert.doesNotMatch(value, /ignore:\s*use_build_context_synchronously/u);
    assert.doesNotMatch(value, /Future(?:<void>)?\.delayed|Timer\s*\(/u);
  }
});
