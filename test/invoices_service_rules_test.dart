import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/invoices_service.dart';

import 'support/test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final owner = buildTestUser('owner-1', name: 'Walid');
  late final renter = buildTestUser('renter-1', name: 'Julia');
  late final item = buildTestItem(
    id: 'item-1',
    ownerId: 'owner-1',
    title: 'QNAP NAS',
  );

  setUp(() async {
    await seedCoreBookingState(
      owner: owner,
      renter: renter,
      item: item,
      requests: [
        buildTestRequest(
          id: 'req-completed',
          itemId: item.id,
          ownerId: owner.id,
          renterId: renter.id,
          status: 'completed',
        ),
        buildTestRequest(
          id: 'req-review-hold',
          itemId: item.id,
          ownerId: owner.id,
          renterId: renter.id,
          status: 'completed',
          needsReview: true,
        ),
        buildTestRequest(
          id: 'req-cancel-owner',
          itemId: item.id,
          ownerId: owner.id,
          renterId: renter.id,
          status: 'cancelled',
          cancelledBy: 'owner',
        ),
      ],
    );
  });

  test(
    'completed renter booking yields invoice and owner booking yields payment plus fee',
    () async {
      final renterDocs = await InvoicesService.getInvoicesForUser(renter.id);
      final ownerDocs = await InvoicesService.getInvoicesForUser(owner.id);

      expect(
        renterDocs
            .where(
              (d) => d.requestId == 'req-completed' && d.type.name == 'invoice',
            )
            .length,
        1,
      );
      expect(
        ownerDocs
            .where(
              (d) => d.requestId == 'req-completed' && d.type.name == 'payment',
            )
            .length,
        1,
      );
      expect(
        ownerDocs
            .where(
              (d) => d.requestId == 'req-completed' && d.type.name == 'fee',
            )
            .length,
        1,
      );
    },
  );

  test('needsReview blocks invoice and payout document generation', () async {
    final ownerDocs = await InvoicesService.getInvoicesForUser(owner.id);
    final renterDocs = await InvoicesService.getInvoicesForUser(renter.id);

    expect(
      ownerDocs.where(
        (d) => d.requestId == 'req-review-hold' && d.type.name == 'payment',
      ),
      isEmpty,
    );
    expect(
      ownerDocs.where(
        (d) => d.requestId == 'req-review-hold' && d.type.name == 'fee',
      ),
      isEmpty,
    );
    expect(
      renterDocs.where(
        (d) => d.requestId == 'req-review-hold' && d.type.name == 'invoice',
      ),
      isEmpty,
    );
  });

  test('owner cancellation produces full renter refund document', () async {
    final renterDocs = await InvoicesService.getInvoicesForUser(renter.id);
    final refund = renterDocs.singleWhere(
      (d) => d.requestId == 'req-cancel-owner' && d.type.name == 'refund',
    );
    final invoice = renterDocs.singleWhere(
      (d) => d.requestId == 'req-cancel-owner' && d.type.name == 'invoice',
    );

    expect(refund.amount, invoice.amount);
  });
}
