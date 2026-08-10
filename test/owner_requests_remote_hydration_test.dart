import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner requests hydrate fresh backend participants and listings', () async {
    final source =
        await File('lib/screens/owner_requests_screen.dart').readAsString();
    final loadStart = source.indexOf('Future<void> _load() async');
    final demoStart = source.indexOf('Future<({String ownerId', loadStart);

    expect(loadStart, greaterThanOrEqualTo(0));
    expect(demoStart, greaterThan(loadStart));

    final loadSource = source.substring(loadStart, demoStart);
    expect(loadSource, contains('DataService.getItemById(request.itemId)'));
    expect(loadSource, contains('DataService.getUserById(request.renterId)'));
    expect(loadSource, isNot(contains('DataService.getUsers()')));
    expect(loadSource, isNot(contains('DataService.getItems()')));
  });
}
