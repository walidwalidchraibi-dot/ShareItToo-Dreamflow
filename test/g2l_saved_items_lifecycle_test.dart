import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('privacy export includes every local Gemerkt store without a cart claim',
      () async {
    final lists = jsonEncode(<Map<String, Object>>[
      <String, Object>{
        'id': 'wl_existing_custom',
        'name': 'Renovierung',
        'system': false,
      },
    ]);
    final assignments = jsonEncode(<String, String>{
      'item-existing-2': 'wl_existing_custom',
    });
    SharedPreferences.setMockInitialValues(<String, Object>{
      'saved_item_ids': <String>['item-existing-1'],
      'wishlists_meta_v1': lists,
      'wishlist_assign_v1': assignments,
    });

    final exported = await DataService.exportSavedItemsForPrivacy();

    expect(exported['scope'], 'local-device');
    expect(exported['terminology'], 'Gemerkt');
    expect(exported['binding'], 'non-binding-no-reservation');
    expect(exported['legacySavedItemIds'], <String>['item-existing-1']);
    expect(exported['lists'], <Map<String, Object>>[
      <String, Object>{
        'id': 'wl_existing_custom',
        'name': 'Renovierung',
        'system': false,
      },
    ]);
    expect(exported['itemAssignments'], <String, String>{
      'item-existing-2': 'wl_existing_custom',
    });
    expect(exported['persistentRentalCart'], isFalse);
    expect(exported['persistentProjectCart'], isFalse);
  });

  test('confirmed account deletion removes only local Gemerkt stores', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'saved_item_ids': <String>['item-existing-1'],
      'wishlists_meta_v1': '[]',
      'wishlist_assign_v1': '{}',
      'app_language_code': 'de',
    });

    await DataService.clearSavedItemsForAccountDeletion();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('saved_item_ids'), isFalse);
    expect(prefs.containsKey('wishlists_meta_v1'), isFalse);
    expect(prefs.containsKey('wishlist_assign_v1'), isFalse);
    expect(prefs.getString('app_language_code'), 'de');
  });
}
