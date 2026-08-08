import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lendify/models/user.dart';
import 'package:lendify/services/auth_service.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:lendify/services/data_service.dart';

class AccountDeletionBlocker {
  final String id;
  final String label;
  final int count;

  const AccountDeletionBlocker(
      {required this.id, required this.label, required this.count});
}

class AccountDeletionPreflightResult {
  final bool canDelete;
  final List<AccountDeletionBlocker> blockers;

  const AccountDeletionPreflightResult(
      {required this.canDelete, required this.blockers});
}

/// Local-only MVP account deletion flow.
///
/// - Performs a preflight check (bookings/payments/conflicts) before allowing deletion.
/// - When allowed, anonymizes user data and deactivates listings.
/// - Designed so it can be swapped to a backend implementation later.
class AccountDeletionService {
  static Future<AccountDeletionPreflightResult> preflightCheck(
      User user) async {
    try {
      if (BackendConfig.enabled) {
        final remote = await BackendRepository.accountDeletionPreflight();
        final rawBlockers = remote['blockers'];
        final blockers = rawBlockers is List
            ? rawBlockers
                .whereType<Map>()
                .map((value) => Map<String, dynamic>.from(value))
                .map((value) => AccountDeletionBlocker(
                      id: value['id']?.toString() ?? 'unknown',
                      label: value['label']?.toString() ?? 'Offener Vorgang',
                      count: (value['count'] as num?)?.toInt() ?? 1,
                    ))
                .toList()
            : <AccountDeletionBlocker>[];
        return AccountDeletionPreflightResult(
          canDelete: remote['canDelete'] == true && blockers.isEmpty,
          blockers: blockers,
        );
      }
      final now = DateTime.now();
      final renterReqs = await DataService.getRentalRequestsForRenter(user.id);
      final ownerReqs = await DataService.getRentalRequestsForOwner(user.id);

      int runningBookings =
          renterReqs.where((r) => r.status == 'running').length;
      int upcomingBookings = renterReqs.where((r) {
        if (r.status == 'running' ||
            r.status == 'completed' ||
            r.status == 'declined' ||
            r.status == 'cancelled') {
          return false;
        }
        return r.start.isAfter(now);
      }).length;

      int runningRentalsAsOwner =
          ownerReqs.where((r) => r.status == 'running').length;
      int upcomingRentalsAsOwner = ownerReqs.where((r) {
        if (r.status == 'running' ||
            r.status == 'completed' ||
            r.status == 'declined' ||
            r.status == 'cancelled') {
          return false;
        }
        return r.start.isAfter(now);
      }).length;

      // Payments & disputes are not yet implemented without backend.
      // Keep the structure so the UI/logic remains scalable.
      const int openPayouts = 0;
      const int openFees = 0;
      const int paymentProcessing = 0;
      const int openDisputes = 0;
      const int openSupportTickets = 0;

      final blockers = <AccountDeletionBlocker>[
        if (runningBookings > 0)
          AccountDeletionBlocker(
              id: 'running_bookings',
              label:
                  '$runningBookings laufende Buchung${runningBookings == 1 ? '' : 'en'}',
              count: runningBookings),
        if (upcomingBookings > 0)
          AccountDeletionBlocker(
              id: 'upcoming_bookings',
              label:
                  '$upcomingBookings kommende Buchung${upcomingBookings == 1 ? '' : 'en'}',
              count: upcomingBookings),
        if (runningRentalsAsOwner > 0)
          AccountDeletionBlocker(
              id: 'running_rentals_owner',
              label:
                  '$runningRentalsAsOwner laufende Anmietung${runningRentalsAsOwner == 1 ? '' : 'en'} (als Vermieter)',
              count: runningRentalsAsOwner),
        if (upcomingRentalsAsOwner > 0)
          AccountDeletionBlocker(
              id: 'upcoming_rentals_owner',
              label:
                  '$upcomingRentalsAsOwner kommende Anmietung${upcomingRentalsAsOwner == 1 ? '' : 'en'} (als Vermieter)',
              count: upcomingRentalsAsOwner),
        if (openPayouts > 0)
          const AccountDeletionBlocker(
              id: 'open_payouts',
              label: 'Offene Auszahlung',
              count: openPayouts),
        if (openFees > 0)
          const AccountDeletionBlocker(
              id: 'open_fees', label: 'Offene Gebühren', count: openFees),
        if (paymentProcessing > 0)
          const AccountDeletionBlocker(
              id: 'payment_processing',
              label: 'Laufende Zahlungsabwicklung',
              count: paymentProcessing),
        if (openDisputes > 0)
          const AccountDeletionBlocker(
              id: 'open_disputes',
              label: 'Offener Streitfall',
              count: openDisputes),
        if (openSupportTickets > 0)
          const AccountDeletionBlocker(
              id: 'open_support',
              label: 'Offenes Supportticket',
              count: openSupportTickets),
      ];

      return AccountDeletionPreflightResult(
          canDelete: blockers.isEmpty, blockers: blockers);
    } catch (e) {
      debugPrint('[AccountDeletionService] preflightCheck failed: $e');
      // Fail closed (block deletion) to be safe.
      return const AccountDeletionPreflightResult(
        canDelete: false,
        blockers: [
          AccountDeletionBlocker(
              id: 'unknown',
              label: 'Systemprüfung konnte nicht abgeschlossen werden',
              count: 1),
        ],
      );
    }
  }

  static Future<void> deleteAccount({
    required User user,
    required String currentPassword,
  }) async {
    try {
      if (BackendConfig.enabled) {
        await BackendRepository.deleteAccount(currentPassword: currentPassword);
        await AuthService.clearSession();
        await DataService.clearCurrentUserAndMarkDeleted();
        return;
      }
      await DataService.anonymizeAndDeactivateUser(userId: user.id);
      await DataService.deactivateAllListingsForUser(user.id);
      await DataService.archiveAllMessageThreadsForUser(user.id);
      await DataService.clearCurrentUserAndMarkDeleted();
    } catch (e) {
      debugPrint('[AccountDeletionService] deleteAccount failed: $e');
      rethrow;
    }
  }
}
