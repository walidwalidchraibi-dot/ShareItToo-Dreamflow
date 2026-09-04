import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lendify/services/auth_service.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/backend_http.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/local_principal_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocalPrincipalActionOwner> useSession(String role) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      'auth_session_v1',
      jsonEncode({
        'userId': 'fixture-$role',
        'sessionId': 'fixture-session-$role',
        'email': 'fixture-$role@example.invalid',
        'createdAt': '2026-09-04T00:00:00Z',
        'accessToken': 'fixture-access-$role',
        'refreshToken': 'fixture-refresh-$role',
        'accessTokenExpiresAt': '2099-01-01T00:00:00Z',
      }));
  return LocalPrincipalActionOwner.capture();
}

Future<Map<String, dynamic>> put(AuthSessionOwner owner, bool item) => item
    ? BackendRepository.putRentalCartItemForOwner(
        owner: owner,
        id: 'fixture-item',
        listingId: 'fixture-listing',
        startDate: '2026-09-10',
        endDate: '2026-09-11',
        projectId: 'fixture-project')
    : BackendRepository.putRentalCartProjectForOwner(
        owner: owner, id: 'fixture-project', title: 'Synthetic A project');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  if (!BackendConfig.enabled) {
    test('disabled backend cannot perform a bound cart upsert', () async {
      final owner = await useSession('a');
      var calls = 0;
      await http.runWithClient(() async {
        await expectLater(
            put(owner.sessionOwner!, false), throwsA(isA<BackendException>()));
      },
          () => MockClient((_) async {
                calls++;
                throw StateError('Unexpected request');
              }));
      expect(calls, 0);
    });
    return;
  }

  for (final item in [false, true]) {
    test('bound cart upsert item=$item uses A only', () async {
      final owner = await useSession('a');
      await http.runWithClient(() async {
        expect(await put(owner.sessionOwner!, item),
            {'projects': [], 'items': []});
      },
          () => MockClient((request) async {
                expect(request.method, 'PUT');
                expect(request.headers['Authorization'],
                    'Bearer fixture-access-a');
                expect(
                    request.url.path,
                    item
                        ? '/api/v1/rental-cart/items/fixture-item'
                        : '/api/v1/rental-cart/projects/fixture-project');
                return http.Response(
                    '{"cart":{"projects":[],"items":[]}}', 200);
              }));
    });
    test('stale cart upsert item=$item never sends B credentials', () async {
      final owner = await useSession('a');
      await useSession('b');
      var calls = 0;
      await http.runWithClient(() async {
        await expectLater(
            put(owner.sessionOwner!, item), throwsA(isA<BackendException>()));
      },
          () => MockClient((_) async {
                calls++;
                return http.Response('{}', 200);
              }));
      expect(calls, 0);
    });
    test('cart upsert item=$item 401 cannot refresh/retry as B', () async {
      final owner = await useSession('a');
      var calls = 0;
      await http.runWithClient(() async {
        await expectLater(
            put(owner.sessionOwner!, item), throwsA(isA<BackendException>()));
      },
          () => MockClient((request) async {
                calls++;
                expect(request.headers['Authorization'],
                    'Bearer fixture-access-a');
                await useSession('b');
                return http.Response('{"error":"session_expired"}', 401);
              }));
      expect(calls, 1);
      expect((await AuthService.readSession())?.userId, 'fixture-b');
    });
  }

  test('server confirms A project after B switch: result rejected, B preserved',
      () async {
    final owner = await useSession('a');
    var calls = 0;
    await http.runWithClient(() async {
      await expectLater(
          DataService.addRentalCartProject(
              title: 'Synthetic A project', expectedOwner: owner),
          throwsStateError);
    },
        () => MockClient((request) async {
              calls++;
              expect(
                  request.headers['Authorization'], 'Bearer fixture-access-a');
              expect(request.method, 'PUT');
              expect(request.url.path,
                  startsWith('/api/v1/rental-cart/projects/'));
              await useSession('b');
              return http.Response(
                  jsonEncode({
                    'cart': {
                      'projects': [
                        {
                          'id': request.url.pathSegments.last,
                          'title': 'Synthetic A project'
                        }
                      ],
                      'items': []
                    }
                  }),
                  200);
            }));
    expect(calls, 1);
    expect((await AuthService.readSession())?.userId, 'fixture-b');
  });

  test('guest sync interrupted after A upsert retains original guest intent',
      () async {
    await DataService.addRentalCartProject(title: 'Guest intent');
    final owner = await useSession('a');
    var calls = 0;
    await http.runWithClient(() async {
      await expectLater(
          DataService.syncGuestRentalCartAfterAuthentication(
              expectedOwner: owner),
          throwsStateError);
    },
        () => MockClient((request) async {
              calls++;
              expect(
                  request.headers['Authorization'], 'Bearer fixture-access-a');
              await useSession('b');
              return http.Response('{"cart":{"projects":[],"items":[]}}', 200);
            }));
    expect(calls, 1);
    final prefs = await SharedPreferences.getInstance();
    final registry = jsonDecode(prefs.getString('rental_cart_v2')!) as Map;
    final guest = registry['principals']['guest'] as Map;
    expect(guest['cart']['projects'].single['title'], 'Guest intent');
    expect(guest['syncOwnerToken'], owner.principal.token);
    expect((await AuthService.readSession())?.userId, 'fixture-b');
  });
}
