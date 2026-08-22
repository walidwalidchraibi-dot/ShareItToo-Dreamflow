import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../../lib/screens/ongoing_owner_detail_screen.dart', import.meta.url),
  'utf8',
);
const body = source.match(
  /Widget _buildOngoingBody[\s\S]*?\n  Future<void> _downloadReceiptPdf/u,
)?.[0];
const maps = source.match(
  /Future<void> _openMaps[\s\S]*?\n  String _computeBookingId/u,
)?.[0];
const completion = source.match(
  /Future<void> _completeOwnerReturnWithSideEffects[\s\S]*?\n  Future<void> _startPickupFlowOwner/u,
)?.[0];
const pickup = source.match(
  /Future<void> _startPickupFlowOwner[\s\S]*?\n  void _showQrOverlay/u,
)?.[0];

assert.ok(body, 'expected owner detail body');
assert.ok(maps, 'expected owner maps helper');
assert.ok(completion, 'expected owner return completion helper');
assert.ok(pickup, 'expected owner pickup helper');

test('both handover starters prove the exact body context after time lookup', () => {
  assert.match(
    body,
    /if \(!await _timeConfirmedForStart\([\s\S]*?isReturn: false,[\s\S]*?\)\) \{\s+return;\s+\}\s+if \(!context\.mounted\) return;\s+await _startPickupFlowOwner\(\s+context,/u,
  );
  assert.match(
    body,
    /if \(!await _timeConfirmedForStart\([\s\S]*?isReturn: true,[\s\S]*?\)\) \{\s+return;\s+\}\s+if \(!context\.mounted\) return;\s+await _startReturnFlow\(context,/u,
  );
});

test('maps failure feedback requires the exact caller context', () => {
  assert.match(
    maps,
    /final launched = await launchUrl\([\s\S]*?\);\s+if \(!context\.mounted\) return;\s+if \(!launched\) \{\s+_toast\(context,/u,
  );
  assert.match(
    maps,
    /catch \(_\) \{\s+if \(!context\.mounted\) return;\s+_toast\(context,/u,
  );
});

test('owner return completion uses its owning State lifecycle', () => {
  assert.match(
    completion,
    /final ownerUserId = await _guardAuthenticatedOwner\(req\.ownerId\);\s+if \(!mounted\) return;\s+if \(ownerUserId == null\) return;/u,
  );
});

test('pickup challenge proves its exact caller context before the stepper', () => {
  assert.match(
    pickup,
    /if \(challenge == null\) \{\s+if \(!context\.mounted\) return;[\s\S]*?return;\s+\}\s+if \(!context\.mounted\) return;\s+await ReturnHandoverStepperSheet\.push\(\s+context,/u,
  );
});

test('handover and maps fixes contain no timing or lint accommodation', () => {
  assert.doesNotMatch(body, /ignore:\s*use_build_context_synchronously/u);
  for (const value of [maps, completion, pickup]) {
    assert.doesNotMatch(value, /ignore:\s*use_build_context_synchronously/u);
    assert.doesNotMatch(value, /Future(?:<void>)?\.delayed|Timer\s*\(/u);
  }
});
