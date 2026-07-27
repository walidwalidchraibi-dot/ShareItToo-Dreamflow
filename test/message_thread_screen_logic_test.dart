import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/widgets/return_handover_stepper_sheet.dart';

void main() {
  test('return handover confirmation requires confirmed result', () {
    expect(didConfirmReturnHandover(null), isFalse);
    expect(
      didConfirmReturnHandover(
        const ReturnHandoverStepResult(confirmed: false, galleryUsed: true),
      ),
      isFalse,
    );
    expect(
      didConfirmReturnHandover(
        const ReturnHandoverStepResult(confirmed: true, galleryUsed: false),
      ),
      isTrue,
    );
  });
}
