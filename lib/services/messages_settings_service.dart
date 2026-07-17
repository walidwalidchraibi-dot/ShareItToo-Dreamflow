import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WhoCanWrite { everyone, acceptedRequestOnly }

enum MediaAutoDownload { wifi, always, never }

class TranslationLanguageOption {
  final String code;
  final String label;
  const TranslationLanguageOption({required this.code, required this.label});
}

const List<TranslationLanguageOption> translationLanguageOptions = [
  TranslationLanguageOption(code: 'ar', label: 'Arabisch'),
  TranslationLanguageOption(code: 'de', label: 'Deutsch'),
  TranslationLanguageOption(code: 'en', label: 'Englisch'),
  TranslationLanguageOption(code: 'fr', label: 'Französisch'),
];

String translationLanguageLabel(String code) {
  final normalized = code.trim().toLowerCase();
  for (final opt in translationLanguageOptions) {
    if (normalized == opt.code || normalized.startsWith('${opt.code}-')) return opt.label;
  }
  final fallback = translationLanguageOptions.firstWhere(
    (o) => o.code == 'de',
    orElse: () => translationLanguageOptions.first,
  );
  return fallback.label;
}

/// Local-only message/chat settings for the in-app communication hub.
///
/// Stored via SharedPreferences (no backend connected).
class MessagesSettings {
  final bool muteAll;
  final bool sendReadReceipts;
  final bool showChatPreview;
  final bool newMessagesNotif;
  final bool handoverReturnReminders;
  final bool openTimeConfirmations;
  final bool supportCaseUpdates;

  final WhoCanWrite whoCanWrite;
  final bool autoSaveHandoverPhotos;
  final bool handoverReminders;
  final bool saveReceiptsLocally;
  final bool showQrCodeHints;

  final bool autoArchiveChats;
  final bool hideCompletedChats;
  final MediaAutoDownload mediaAutoDownload;

  final bool autoTranslateChat;
  final bool showOriginalMessages;
  final String preferredLanguageCode;

  const MessagesSettings({
    required this.muteAll,
    required this.sendReadReceipts,
    required this.showChatPreview,
    required this.newMessagesNotif,
    required this.handoverReturnReminders,
    required this.openTimeConfirmations,
    required this.supportCaseUpdates,
    required this.whoCanWrite,
    required this.autoSaveHandoverPhotos,
    required this.handoverReminders,
    required this.saveReceiptsLocally,
    required this.showQrCodeHints,
    required this.autoArchiveChats,
    required this.hideCompletedChats,
    required this.mediaAutoDownload,
    required this.autoTranslateChat,
    required this.showOriginalMessages,
    required this.preferredLanguageCode,
  });

  factory MessagesSettings.defaults() => const MessagesSettings(
    muteAll: false,
    sendReadReceipts: true,
    showChatPreview: true,
    newMessagesNotif: true,
    handoverReturnReminders: true,
    openTimeConfirmations: true,
    supportCaseUpdates: true,
    whoCanWrite: WhoCanWrite.acceptedRequestOnly,
    autoSaveHandoverPhotos: true,
    handoverReminders: true,
    saveReceiptsLocally: true,
    showQrCodeHints: true,
    autoArchiveChats: false,
    hideCompletedChats: false,
    mediaAutoDownload: MediaAutoDownload.wifi,
    autoTranslateChat: false,
    showOriginalMessages: false,
    preferredLanguageCode: 'auto',
  );

  MessagesSettings normalizedForCurrentProductRules() => copyWith(
    muteAll: false,
    sendReadReceipts: true,
    newMessagesNotif: true,
    handoverReturnReminders: true,
    openTimeConfirmations: true,
    supportCaseUpdates: true,
    showQrCodeHints: true,
    autoArchiveChats: false,
    hideCompletedChats: false,
  );

  MessagesSettings copyWith({
    bool? muteAll,
    bool? sendReadReceipts,
    bool? showChatPreview,
    bool? newMessagesNotif,
    bool? handoverReturnReminders,
    bool? openTimeConfirmations,
    bool? supportCaseUpdates,
    WhoCanWrite? whoCanWrite,
    bool? autoSaveHandoverPhotos,
    bool? handoverReminders,
    bool? saveReceiptsLocally,
    bool? showQrCodeHints,
    bool? autoArchiveChats,
    bool? hideCompletedChats,
    MediaAutoDownload? mediaAutoDownload,
    bool? autoTranslateChat,
    bool? showOriginalMessages,
    String? preferredLanguageCode,
  }) => MessagesSettings(
    muteAll: muteAll ?? this.muteAll,
    sendReadReceipts: sendReadReceipts ?? this.sendReadReceipts,
    showChatPreview: showChatPreview ?? this.showChatPreview,
    newMessagesNotif: newMessagesNotif ?? this.newMessagesNotif,
    handoverReturnReminders: handoverReturnReminders ?? this.handoverReturnReminders,
    openTimeConfirmations: openTimeConfirmations ?? this.openTimeConfirmations,
    supportCaseUpdates: supportCaseUpdates ?? this.supportCaseUpdates,
    whoCanWrite: whoCanWrite ?? this.whoCanWrite,
    autoSaveHandoverPhotos: autoSaveHandoverPhotos ?? this.autoSaveHandoverPhotos,
    handoverReminders: handoverReminders ?? this.handoverReminders,
    saveReceiptsLocally: saveReceiptsLocally ?? this.saveReceiptsLocally,
    showQrCodeHints: showQrCodeHints ?? this.showQrCodeHints,
    autoArchiveChats: autoArchiveChats ?? this.autoArchiveChats,
    hideCompletedChats: hideCompletedChats ?? this.hideCompletedChats,
    mediaAutoDownload: mediaAutoDownload ?? this.mediaAutoDownload,
    autoTranslateChat: autoTranslateChat ?? this.autoTranslateChat,
    showOriginalMessages: showOriginalMessages ?? this.showOriginalMessages,
    preferredLanguageCode: preferredLanguageCode ?? this.preferredLanguageCode,
  );

  Map<String, dynamic> toJson() => {
    'showChatPreview': showChatPreview,
    'whoCanWrite': whoCanWrite.name,
    'autoSaveHandoverPhotos': autoSaveHandoverPhotos,
    'handoverReminders': handoverReminders,
    'saveReceiptsLocally': saveReceiptsLocally,
    'mediaAutoDownload': mediaAutoDownload.name,
    'autoTranslateChat': autoTranslateChat,
    'showOriginalMessages': showOriginalMessages,
    'preferredLanguageCode': preferredLanguageCode,
  };

  factory MessagesSettings.fromJson(Map<String, dynamic> json) {
    final d = MessagesSettings.defaults();
    bool b(String k, bool v) {
      final raw = json[k];
      if (raw is bool) return raw;
      return v;
    }

    String s(String k, String v) {
      final raw = json[k];
      if (raw is String && raw.trim().isNotEmpty) return raw;
      return v;
    }

    WhoCanWrite who(String k, WhoCanWrite v) {
      final raw = json[k];
      if (raw is String) {
        for (final e in WhoCanWrite.values) {
          if (e.name == raw) return e;
        }
      }
      return v;
    }

    MediaAutoDownload media(String k, MediaAutoDownload v) {
      final raw = json[k];
      if (raw is String) {
        for (final e in MediaAutoDownload.values) {
          if (e.name == raw) return e;
        }
      }
      return v;
    }

    return MessagesSettings(
      muteAll: b('muteAll', d.muteAll),
      sendReadReceipts: b('sendReadReceipts', d.sendReadReceipts),
      showChatPreview: b('showChatPreview', d.showChatPreview),
      newMessagesNotif: b('newMessagesNotif', d.newMessagesNotif),
      handoverReturnReminders: b('handoverReturnReminders', d.handoverReturnReminders),
      openTimeConfirmations: b('openTimeConfirmations', d.openTimeConfirmations),
      supportCaseUpdates: b('supportCaseUpdates', d.supportCaseUpdates),
      whoCanWrite: who('whoCanWrite', d.whoCanWrite),
      autoSaveHandoverPhotos: b('autoSaveHandoverPhotos', d.autoSaveHandoverPhotos),
      handoverReminders: b('handoverReminders', d.handoverReminders),
      saveReceiptsLocally: b('saveReceiptsLocally', d.saveReceiptsLocally),
      showQrCodeHints: b('showQrCodeHints', d.showQrCodeHints),
      autoArchiveChats: b('autoArchiveChats', d.autoArchiveChats),
      hideCompletedChats: b('hideCompletedChats', d.hideCompletedChats),
      mediaAutoDownload: media('mediaAutoDownload', d.mediaAutoDownload),
      autoTranslateChat: b('autoTranslateChat', d.autoTranslateChat),
      showOriginalMessages: b('showOriginalMessages', d.showOriginalMessages),
      preferredLanguageCode: s('preferredLanguageCode', d.preferredLanguageCode),
    );
  }
}

class MessagesSettingsService {
  static const _key = 'messages_settings_v1';

  static Future<MessagesSettings> get() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return MessagesSettings.defaults().normalizedForCurrentProductRules();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return MessagesSettings.defaults().normalizedForCurrentProductRules();
      final settings = MessagesSettings.fromJson(Map<String, dynamic>.from(decoded)).normalizedForCurrentProductRules();
      final normalizedRaw = jsonEncode(settings.toJson());
      if (normalizedRaw != raw) {
        await prefs.setString(_key, normalizedRaw);
      }
      return settings;
    } catch (e) {
      debugPrint('[MessagesSettingsService] get failed: $e');
      return MessagesSettings.defaults().normalizedForCurrentProductRules();
    }
  }

  static Future<void> set(MessagesSettings value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = value.normalizedForCurrentProductRules();
    final ok = await prefs.setString(_key, jsonEncode(normalized.toJson()));
    if (!ok) {
      throw Exception('Messages settings could not be persisted.');
    }
  }

  static Future<void> reset() async => set(MessagesSettings.defaults());
}
