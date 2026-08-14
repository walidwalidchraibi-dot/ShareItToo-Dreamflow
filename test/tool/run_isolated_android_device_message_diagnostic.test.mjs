import assert from 'node:assert/strict';
import test from 'node:test';

import {
  sanitizedChildFailure,
} from '../../tool/run_isolated_android_device_message_diagnostic.mjs';

test('preserves a bounded generic child diagnostic failure', () => {
  assert.equal(
    sanitizedChildFailure({
      stderr: 'ERROR: The controlled message did not appear after realtime recovery.\n',
    }),
    'The controlled message did not appear after realtime recovery.',
  );
});

test('rejects child failure details containing private-looking values', () => {
  assert.equal(
    sanitizedChildFailure({
      stderr: 'ERROR: Account test@example.invalid could not use token 123456789.\n',
    }),
    null,
  );
});

test('rejects unstructured child stderr', () => {
  assert.equal(sanitizedChildFailure({ stderr: 'unexpected stack trace\n' }), null);
});
