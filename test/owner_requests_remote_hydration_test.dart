import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner requests hydrate fresh backend participants and listings',
      () async {
    final source =
        await File('lib/screens/owner_requests_screen.dart').readAsString();
    final loadStart = source.indexOf('Future<void> _load() async');
    final demoStart = source.indexOf(')> _buildDemoOwnerEntries', loadStart);

    expect(loadStart, greaterThanOrEqualTo(0));
    expect(demoStart, greaterThan(loadStart));

    final loadSource = source.substring(loadStart, demoStart);
    expect(loadSource, contains('final items = await DataService.getItems()'));
    expect(loadSource, contains('final users = await DataService.getUsers()'));
    expect(loadSource, contains('DataService.getUserById(request.renterId)'));
    expect(
        loadSource, isNot(contains('DataService.getItemById(request.itemId)')));
    expect(
      'DataService.getItems()'.allMatches(loadSource),
      hasLength(1),
      reason: 'the remote catalog must be loaded once per screen refresh',
    );
    expect(
      'DataService.getUsers()'.allMatches(loadSource),
      hasLength(1),
      reason: 'the cached participant list must be loaded once per refresh',
    );
  });
}
