import 'package:flutter/foundation.dart' show protected;
import 'package:lendify/models/security.dart';
import 'package:lendify/services/auth_service.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/backend_repository.dart';

/// Server-authoritative account security controls.
///
/// The device-local fallback deliberately implements none of these controls.
/// A successful return therefore always means that the configured SIT backend
/// confirmed the operation for the exact session that invoked it.
class AccountSecurityService {
  static const int _maxSessions = 100;
  static const int _maxSessionIdLength = 80;
  static const int _maxDeviceNameLength = 160;
  static const int _maxLocationLength = 200;
  static const int _maxPasswordLength = 1024;

  const AccountSecurityService();

  bool get isAvailable => BackendConfig.enabled;

  @protected
  Future<AuthSession?> readSession() => AuthService.readSession();

  @protected
  Future<List<Map<String, dynamic>>> fetchSessions() =>
      BackendRepository.getAuthSessions();

  @protected
  Future<void> revokeRemoteSession(String sessionId) =>
      BackendRepository.revokeAuthSession(sessionId);

  @protected
  Future<void> logoutAllRemoteSessions() =>
      BackendRepository.logoutAllSessions();

  @protected
  Future<void> changeRemotePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      BackendRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  @protected
  Future<bool> clearCurrentSessionIfMatches({
    required String userId,
    required String sessionId,
    required String email,
  }) =>
      AuthService.clearSessionIfMatches(
        userId: userId,
        sessionId: sessionId,
        email: email,
      );

  Future<List<SecurityDevice>> getSessions() async {
    final marker = await _requireCurrentSession();
    final raw = await fetchSessions();
    await _assertSameCurrentSession(marker);
    return _decodeSessions(raw, expectedCurrentSessionId: marker.sessionId);
  }

  Future<void> revokeSession(String sessionId) async {
    final target = sessionId.trim();
    if (target.isEmpty || target.length > _maxSessionIdLength) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    final marker = await _requireCurrentSession();
    if (target == marker.sessionId) {
      throw StateError(
        'Die aktuelle Sitzung darf nicht als fremdes Gerät widerrufen werden.',
      );
    }
    await revokeRemoteSession(target);
    await _assertSameCurrentSession(marker);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty ||
        currentPassword.length > _maxPasswordLength ||
        newPassword.length < 10 ||
        newPassword.length > _maxPasswordLength) {
      throw ArgumentError('Ungültige Passwortlänge.');
    }
    final marker = await _requireCurrentSession();
    await changeRemotePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _assertSameCurrentSession(marker);
    final cleared = await clearCurrentSessionIfMatches(
      userId: marker.userId,
      sessionId: marker.sessionId,
      email: marker.email,
    );
    if (!cleared || await readSession() != null) {
      throw StateError(
        'Die bestätigte Passwortänderung konnte lokal nicht sicher abgeschlossen werden.',
      );
    }
  }

  Future<void> logoutAllSessions() async {
    final marker = await _requireCurrentSession();
    await logoutAllRemoteSessions();
    await _assertSameCurrentSession(marker);
    final cleared = await clearCurrentSessionIfMatches(
      userId: marker.userId,
      sessionId: marker.sessionId,
      email: marker.email,
    );
    if (!cleared || await readSession() != null) {
      throw StateError(
        'Die bestätigte Abmeldung konnte lokal nicht sicher abgeschlossen werden.',
      );
    }
  }

  Future<_AccountSecuritySessionMarker> _requireCurrentSession() async {
    if (!isAvailable) {
      throw StateError(
        'Kontosicherheit ist ohne die serverseitige Anmeldung nicht verfügbar.',
      );
    }
    final session = await readSession();
    if (session == null) {
      throw StateError('Für Kontosicherheit ist eine Anmeldung erforderlich.');
    }
    final userId = (session.userId ?? '').trim();
    final sessionId = (session.sessionId ?? '').trim();
    final email = session.email.trim().toLowerCase();
    if (userId.isEmpty ||
        userId.length > 256 ||
        sessionId.isEmpty ||
        sessionId.length > _maxSessionIdLength ||
        email.isEmpty ||
        email.length > 320) {
      throw StateError('Die aktuelle Kontositzung ist unvollständig.');
    }
    return _AccountSecuritySessionMarker(
      userId: userId,
      sessionId: sessionId,
      email: email,
    );
  }

  Future<void> _assertSameCurrentSession(
    _AccountSecuritySessionMarker expected,
  ) async {
    final current = await _requireCurrentSession();
    if (current != expected) {
      throw StateError(
          'Die Kontositzung hat sich während der Aktion geändert.');
    }
  }

  static List<SecurityDevice> _decodeSessions(
    List<Map<String, dynamic>> raw, {
    required String expectedCurrentSessionId,
  }) {
    if (raw.isEmpty || raw.length > _maxSessions) {
      throw const FormatException('Ungültige serverseitige Sitzungsliste.');
    }
    final ids = <String>{};
    final devices = <SecurityDevice>[];
    var currentCount = 0;
    for (final entry in raw) {
      final idValue = entry['id'];
      final nameValue = entry['name'];
      final locationValue = entry['location'];
      final lastActiveValue = entry['lastActive'];
      final isThisDeviceValue = entry['isThisDevice'];
      if (idValue is! String ||
          nameValue is! String ||
          locationValue is! String ||
          lastActiveValue is! String ||
          isThisDeviceValue is! bool) {
        throw const FormatException('Ungültige serverseitige Sitzung.');
      }
      final id = idValue.trim();
      final name = nameValue.trim();
      final location = locationValue.trim();
      final lastActive = DateTime.tryParse(lastActiveValue);
      if (id.isEmpty ||
          id.length > _maxSessionIdLength ||
          !ids.add(id) ||
          name.isEmpty ||
          name.length > _maxDeviceNameLength ||
          location.isEmpty ||
          location.length > _maxLocationLength ||
          lastActive == null) {
        throw const FormatException('Ungültige serverseitige Sitzung.');
      }
      if (isThisDeviceValue) {
        currentCount += 1;
        if (id != expectedCurrentSessionId) {
          throw const FormatException(
            'Die aktuelle serverseitige Sitzung ist widersprüchlich.',
          );
        }
      }
      devices.add(SecurityDevice(
        id: id,
        name: name,
        location: location,
        lastActive: lastActive,
        isThisDevice: isThisDeviceValue,
      ));
    }
    if (currentCount != 1) {
      throw const FormatException(
        'Die aktuelle serverseitige Sitzung fehlt oder ist mehrdeutig.',
      );
    }
    return List<SecurityDevice>.unmodifiable(devices);
  }
}

class _AccountSecuritySessionMarker {
  final String userId;
  final String sessionId;
  final String email;

  const _AccountSecuritySessionMarker({
    required this.userId,
    required this.sessionId,
    required this.email,
  });

  @override
  bool operator ==(Object other) =>
      other is _AccountSecuritySessionMarker &&
      other.userId == userId &&
      other.sessionId == sessionId &&
      other.email == email;

  @override
  int get hashCode => Object.hash(userId, sessionId, email);
}
