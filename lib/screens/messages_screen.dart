import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lendify/models/message.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/screens/messages_settings_screen.dart';
import 'package:lendify/screens/blocked_users_screen.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/services/blocked_users_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/shared_persistence_sync.dart';
import 'package:lendify/services/messages_settings_service.dart';
import 'package:lendify/services/qa_runtime_service.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/user_avatar.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

enum _MessagesFilter { all, bookings, active, archived, blocked, support }

const String _translationDemoThreadId = 'demo_translation_thread';
const String _mutedThreadsKey = 'muted_message_threads_v1';

class MessagesBlockedTabEmptyStateConfig {
  final String title;
  final String body;
  final String buttonLabel;

  const MessagesBlockedTabEmptyStateConfig({
    required this.title,
    required this.body,
    required this.buttonLabel,
  });
}

const messagesBlockedTabEmptyStateConfig = MessagesBlockedTabEmptyStateConfig(
  title: 'Keine blockierten Chats',
  body:
      'Blockierte Gespräche erscheinen hier, wenn mit der blockierten Person bereits ein Chat besteht. Alle blockierten Nutzer verwaltest du in den Kontoeinstellungen.',
  buttonLabel: 'Blockierte Nutzer verwalten',
);

Future<void> openBlockedUsersManagement(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
  );
}

class _MessagesScreenState extends State<MessagesScreen> {
  _MessagesFilter _filter = _MessagesFilter.active;
  List<MessageThread> _activeThreads = [];
  List<MessageThread> _archivedThreads = [];
  User? _currentUser;
  Map<String, User> _usersCache = {};
  Map<String, Item> _itemsCache = {};
  bool _isLoading = true;
  Set<String> _blockedUserIds = const {};
  Set<String> _mutedThreadKeys = const {};
  bool _searchVisible = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  MessagesSettings _messageSettings = MessagesSettings.defaults().normalizedForCurrentProductRules();
  StreamSubscription<String>? _sharedPersistenceSub;
  final SharedPersistenceRefreshCoordinator _sharedPersistenceRefresh =
      SharedPersistenceRefreshCoordinator();

  @override
  void initState() {
    super.initState();
    _loadData();
    _sharedPersistenceSub = SharedPersistenceSync.changes.listen((key) {
      if (!mounted || !SharedPersistenceSync.affectsBookingSync(key)) return;
      unawaited(_sharedPersistenceRefresh.schedule(() async {
        await SharedPersistenceSync.reloadPreferences();
        if (mounted) await _loadData();
      }));
    });
  }


  static String _muteKey({required String threadId, required String userId}) => '$userId::$threadId';

  Future<Set<String>> _loadMutedThreadKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_mutedThreadsKey);
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    } catch (e) {
      debugPrint('MessagesScreen._loadMutedThreadKeys failed: $e');
      return <String>{};
    }
  }

  bool _isThreadMuted(MessageThread thread) {
    final userId = _currentUser?.id;
    if (userId == null) return false;
    return _mutedThreadKeys.contains(_muteKey(threadId: thread.id, userId: userId));
  }

  bool _isOtherUserBlocked(MessageThread thread) {
    final me = _currentUser;
    if (me == null) return false;
    final otherUserId = thread.user1Id == me.id ? thread.user2Id : thread.user1Id;
    return otherUserId.isNotEmpty && _blockedUserIds.contains(otherUserId);
  }


  _MessagesFilter _normalizedFilterForBlocked(Set<String> blockedUserIds) {
    if (_filter == _MessagesFilter.blocked && blockedUserIds.isEmpty) {
      return _MessagesFilter.active;
    }
    return _filter;
  }

  _MessagesEmptyStateConfig _emptyStateConfig() {
    switch (_filter) {
      case _MessagesFilter.active:
        return const _MessagesEmptyStateConfig(
          title: 'Keine aktiven Nachrichten',
          body: 'Sobald eine laufende oder offene Unterhaltung entsteht, erscheint sie hier.',
          buttonLabel: 'Jetzt entdecken',
          buttonIcon: Icons.explore,
        );
      case _MessagesFilter.all:
        return const _MessagesEmptyStateConfig(
          title: 'Noch keine Nachrichten',
          body: 'Deine Gespräche erscheinen hier, sobald du eine Anfrage stellst oder annimmst.',
          buttonLabel: 'Jetzt entdecken',
          buttonIcon: Icons.explore,
        );
      case _MessagesFilter.bookings:
        return const _MessagesEmptyStateConfig(
          title: 'Keine Buchungsnachrichten',
          body: 'Sobald es Nachrichten zu Buchungen gibt, erscheinen sie hier.',
          buttonLabel: 'Jetzt entdecken',
          buttonIcon: Icons.explore,
        );
      case _MessagesFilter.archived:
        return const _MessagesEmptyStateConfig(
          title: 'Keine archivierten Nachrichten',
          body: 'Archivierte Gespräche erscheinen hier.',
          buttonLabel: 'Jetzt entdecken',
          buttonIcon: Icons.explore,
        );
      case _MessagesFilter.support:
        return const _MessagesEmptyStateConfig(
          title: 'Keine Support-Nachrichten',
          body: 'Support-Unterhaltungen erscheinen hier, sobald du den Support kontaktierst.',
          buttonLabel: 'Jetzt entdecken',
          buttonIcon: Icons.explore,
        );
      case _MessagesFilter.blocked:
        return _MessagesEmptyStateConfig(
          title: messagesBlockedTabEmptyStateConfig.title,
          body: messagesBlockedTabEmptyStateConfig.body,
          buttonLabel: messagesBlockedTabEmptyStateConfig.buttonLabel,
          buttonIcon: Icons.block_outlined,
        );
    }
  }

  @override
  void dispose() {
    _sharedPersistenceSub?.cancel();
    _sharedPersistenceRefresh.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = await DataService.getCurrentUser();
      final users = await DataService.getUsers();
      final items = await DataService.getItems();
      final messageSettings = await MessagesSettingsService.get();

      if (user == null) {
        if (!mounted) return;
        setState(() {
          _currentUser = null;
          _activeThreads = const [];
          _archivedThreads = const [];
          _usersCache = const {};
          _itemsCache = const {};
          _blockedUserIds = const {};
          _mutedThreadKeys = const {};
          _messageSettings = messageSettings;
          _filter = _normalizedFilterForBlocked(const <String>{});
          _isLoading = false;
        });
        return;
      }

      final threads = await DataService.getMessageThreadsForUser(user.id);
      final archived = await DataService.getArchivedMessageThreadsForUser(user.id);
      final blockedUserIds = (await BlockedUsersService.getBlockedUserIds()).toSet();
      final mutedThreadKeys = await _loadMutedThreadKeys();
      final usersById = {for (final u in users) u.id: u};
      final itemsById = {for (final i in items) i.id: i};

      if (!mounted) return;

      // If seeding is disabled, the message threads store can be empty, which makes
      // it impossible to QA the chat detail UI. Seed a minimal local support thread
      // (only when empty) and reload once.
      if (threads.isEmpty && archived.isEmpty) {
        if (QaRuntimeService.isEnabled) {
          await DataService.ensureSeededMessageThreadsForUser(user.id);
        }
        final seededThreads = await DataService.getMessageThreadsForUser(user.id);
        final seededArchived = await DataService.getArchivedMessageThreadsForUser(user.id);
        if (!mounted) return;
        if (seededThreads.isNotEmpty || seededArchived.isNotEmpty) {
          final injected = _withTranslationDemoThread(user: user, activeThreads: seededThreads, users: usersById, items: itemsById);
          setState(() {
            _currentUser = user;
            _activeThreads = injected.activeThreads;
            _archivedThreads = seededArchived;
            _usersCache = injected.users;
            _itemsCache = injected.items;
            _blockedUserIds = blockedUserIds;
            _mutedThreadKeys = mutedThreadKeys;
            _messageSettings = messageSettings;
            _filter = _normalizedFilterForBlocked(blockedUserIds);
          _isLoading = false;
          });
          return;
        }

        setState(() {
          _currentUser = user;
          _activeThreads = const [];
          _archivedThreads = const [];
          _usersCache = usersById;
          _itemsCache = itemsById;
          _blockedUserIds = blockedUserIds;
          _mutedThreadKeys = mutedThreadKeys;
          _messageSettings = messageSettings;
          _filter = _normalizedFilterForBlocked(blockedUserIds);
          _isLoading = false;
        });
        return;
      }

      final injected = _withTranslationDemoThread(user: user, activeThreads: threads, users: usersById, items: itemsById);

      setState(() {
        _currentUser = user;
        _activeThreads = injected.activeThreads;
        _archivedThreads = archived;
        _usersCache = injected.users;
        _itemsCache = injected.items;
        _blockedUserIds = blockedUserIds;
        _mutedThreadKeys = mutedThreadKeys;
        _filter = _normalizedFilterForBlocked(blockedUserIds);
          _isLoading = false;
      });
    } catch (e) {
      debugPrint('MessagesScreen._loadData failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ({User user, List<MessageThread> activeThreads, List<MessageThread> archivedThreads, Map<String, User> users, Map<String, Item> items}) _buildDemoMessageState({
    User? baseUser,
    Map<String, User>? users,
    Map<String, Item>? items,
  }) {
    final now = DateTime.now();
    final me = baseUser ?? User(
      id: 'demo_me',
      displayName: 'Du',
      email: 'demo@shareittoo.local',
      preferredLanguage: 'de',
      isVerified: true,
      isBanned: false,
      role: 'user',
      avgRating: 0,
      reviewCount: 0,
      createdAt: now.subtract(const Duration(days: 90)),
    );

    final mila = User(
      id: 'demo_owner',
      displayName: 'Mila Berger',
      email: 'mila@example.com',
      city: 'Berlin',
      preferredLanguage: 'de',
      isVerified: true,
      isBanned: false,
      role: 'user',
      avgRating: 4.9,
      reviewCount: 18,
      createdAt: now.subtract(const Duration(days: 220)),
      photoURL: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&h=150&fit=crop&crop=face',
    );

    final jonas = User(
      id: 'demo_upcoming_owner',
      displayName: 'Jonas Keller',
      email: 'jonas@example.com',
      city: 'Hamburg',
      preferredLanguage: 'de',
      isVerified: true,
      isBanned: false,
      role: 'user',
      avgRating: 4.7,
      reviewCount: 26,
      createdAt: now.subtract(const Duration(days: 150)),
      photoURL: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&h=150&fit=crop&crop=face',
    );

    final lina = User(
      id: 'demo_completed_owner',
      displayName: 'Lina Thomsen',
      email: 'lina@example.com',
      city: 'Köln',
      preferredLanguage: 'de',
      isVerified: false,
      isBanned: false,
      role: 'user',
      avgRating: 4.6,
      reviewCount: 11,
      createdAt: now.subtract(const Duration(days: 310)),
      photoURL: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=150&h=150&fit=crop&crop=face',
    );

    final paula = User(
      id: 'demo_pending_owner',
      displayName: 'Paula Meier',
      email: 'paula@example.com',
      city: 'München',
      preferredLanguage: 'de',
      isVerified: true,
      isBanned: false,
      role: 'user',
      avgRating: 4.8,
      reviewCount: 34,
      createdAt: now.subtract(const Duration(days: 190)),
      photoURL: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&h=150&fit=crop&crop=face',
    );

    final camera = Item(
      id: 'mock_item_camera',
      ownerId: mila.id,
      title: 'Sony Alpha 7 III',
      description: 'Demoartikel für Nachrichtenvorschau',
      categoryId: 'electronics',
      subcategory: 'kameras',
      tags: const ['kamera', 'foto'],
      pricePerDay: 24,
      currency: 'EUR',
      photos: const ['https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=640'],
      locationText: 'Berlin, Mitte',
      lat: 52.52,
      lng: 13.405,
      geohash: 'u33dc0',
      condition: 'good',
      createdAt: now.subtract(const Duration(days: 12)),
      isActive: true,
      verificationStatus: 'verified',
      city: 'Berlin',
      country: 'Deutschland',
    );

    final cargoBike = Item(
      id: 'demo_item_bike',
      ownerId: jonas.id,
      title: 'Urban Arrow Lastenrad',
      description: 'Geräumiges E-Lastenrad für Wochenendausflüge.',
      categoryId: 'fahrzeuge',
      subcategory: 'fahrrad',
      tags: const ['bike', 'cargo'],
      pricePerDay: 29,
      currency: 'EUR',
      photos: const ['https://images.unsplash.com/photo-1502877828070-33b167ad6860?w=640'],
      locationText: 'Hamburg, Sternschanze',
      lat: 53.56,
      lng: 9.97,
      geohash: 'u1x0v9',
      condition: 'excellent',
      createdAt: now.subtract(const Duration(days: 6)),
      isActive: true,
      verificationStatus: 'verified',
      city: 'Hamburg',
      country: 'Deutschland',
    );

    final projector = Item(
      id: 'demo_item_projector',
      ownerId: paula.id,
      title: '4K Beamer Epson',
      description: 'Demo-Beamer für Wohnzimmerkino.',
      categoryId: 'electronics',
      subcategory: 'beamer',
      tags: const ['beamer', '4k'],
      pricePerDay: 18,
      currency: 'EUR',
      photos: const ['https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=640'],
      locationText: 'München, Glockenbach',
      lat: 48.13,
      lng: 11.57,
      geohash: 'u28bn0',
      condition: 'like-new',
      createdAt: now.subtract(const Duration(days: 20)),
      isActive: true,
      verificationStatus: 'verified',
      city: 'München',
      country: 'Deutschland',
    );

    final grill = Item(
      id: 'demo_item_grill',
      ownerId: lina.id,
      title: 'Weber Gasgrill',
      description: 'Demoartikel – Chat ist abgeschlossen.',
      categoryId: 'outdoor',
      subcategory: 'grillen',
      tags: const ['grill', 'outdoor'],
      pricePerDay: 22,
      currency: 'EUR',
      photos: const ['https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=640'],
      locationText: 'Köln, Ehrenfeld',
      lat: 50.95,
      lng: 6.92,
      geohash: 'u1hcy7',
      condition: 'good',
      createdAt: now.subtract(const Duration(days: 40)),
      isActive: true,
      verificationStatus: 'verified',
      city: 'Köln',
      country: 'Deutschland',
    );

    final bookingThread = MessageThread(
      id: 'mock_thread_booking',
      requestId: 'mock_request_booking',
      itemId: camera.id,
      itemTitle: camera.title,
      user1Id: me.id,
      user2Id: mila.id,
      bookingStatus: 'running',
      handoverAt: now.add(const Duration(hours: 3)),
      returnAt: now.add(const Duration(days: 2, hours: 2)),
      otherUserOnline: true,
      messages: [
        Message(
          id: 'mock_msg_1',
          senderId: mila.id,
          text: 'Perfekt — bring bitte nur kurz deinen Ausweis zur Übergabe mit.',
          timestamp: now.subtract(const Duration(minutes: 12)),
          isRead: false,
        ),
      ],
      createdAt: now.subtract(const Duration(days: 1)),
      lastMessageAt: now.subtract(const Duration(minutes: 12)),
    );

    final upcomingThread = MessageThread(
      id: 'mock_thread_upcoming',
      requestId: 'mock_request_upcoming',
      itemId: cargoBike.id,
      itemTitle: cargoBike.title,
      user1Id: me.id,
      user2Id: jonas.id,
      bookingStatus: 'accepted',
      handoverAt: now.add(const Duration(days: 1, hours: 2)),
      returnAt: now.add(const Duration(days: 4)),
      otherUserOnline: false,
      otherUserLastActive: now.subtract(const Duration(hours: 1)),
      messages: [
        Message(
          id: 'mock_msg_u1',
          senderId: jonas.id,
          text: 'Alles klar, Übergabe morgen 10:00 am Schulterblatt passt?',
          timestamp: now.subtract(const Duration(hours: 2, minutes: 10)),
          isRead: true,
        ),
        Message(
          id: 'mock_msg_u2',
          senderId: me.id,
          text: 'Ja, passt! Ich bringe Helm und Kaution mit.',
          timestamp: now.subtract(const Duration(hours: 1, minutes: 55)),
          isRead: true,
        ),
      ],
      createdAt: now.subtract(const Duration(days: 1, hours: 5)),
      lastMessageAt: now.subtract(const Duration(hours: 1, minutes: 55)),
    );

    final pendingThread = MessageThread(
      id: 'mock_thread_pending',
      requestId: 'mock_request_pending',
      itemId: projector.id,
      itemTitle: projector.title,
      user1Id: me.id,
      user2Id: paula.id,
      bookingStatus: 'pending',
      handoverAt: now.add(const Duration(days: 3, hours: 1)),
      returnAt: now.add(const Duration(days: 5, hours: 1)),
      otherUserOnline: false,
      otherUserLastActive: now.subtract(const Duration(hours: 5)),
      messages: [
        Message(
          id: 'mock_msg_p1',
          senderId: me.id,
          text: 'Hi Paula! Anfrage für das Wochenende ist raus – gib gerne kurz Bescheid.',
          timestamp: now.subtract(const Duration(hours: 4, minutes: 10)),
          isRead: true,
        ),
        Message(
          id: 'mock_msg_p2',
          senderId: paula.id,
          text: 'Ich prüfe es heute Abend und sag dann Bescheid.',
          timestamp: now.subtract(const Duration(hours: 3, minutes: 55)),
          isRead: false,
        ),
      ],
      createdAt: now.subtract(const Duration(hours: 8)),
      lastMessageAt: now.subtract(const Duration(hours: 3, minutes: 55)),
    );

    final completedThread = MessageThread(
      id: 'mock_thread_completed',
      requestId: 'mock_request_completed',
      itemId: grill.id,
      itemTitle: grill.title,
      user1Id: me.id,
      user2Id: lina.id,
      bookingStatus: 'completed',
      handoverAt: now.subtract(const Duration(days: 6)),
      returnAt: now.subtract(const Duration(days: 3)),
      otherUserOnline: false,
      otherUserLastActive: now.subtract(const Duration(days: 2)),
      messages: [
        Message(
          id: 'mock_msg_c1',
          senderId: lina.id,
          text: 'Danke fürs Zurückbringen! Ich hoffe, das Grillen war top.',
          timestamp: now.subtract(const Duration(days: 3, hours: 2)),
          isRead: true,
        ),
        Message(
          id: 'mock_msg_c2',
          senderId: me.id,
          text: 'War super, danke! Bewertung kommt gleich.',
          timestamp: now.subtract(const Duration(days: 3, hours: 1, minutes: 50)),
          isRead: true,
        ),
      ],
      createdAt: now.subtract(const Duration(days: 9)),
      lastMessageAt: now.subtract(const Duration(days: 3, hours: 1, minutes: 50)),
    );

    final supportThread = MessageThread(
      id: 'mock_thread_support',
      requestId: 'mock_request_support',
      itemId: 'support',
      itemTitle: 'Support',
      user1Id: me.id,
      user2Id: 'support',
      threadType: 'support',
      otherUserOnline: true,
      messages: [
        Message(
          id: 'mock_msg_2',
          senderId: 'support',
          text: 'Wir haben deine letzte Frage gesehen und melden uns gleich.',
          timestamp: now.subtract(const Duration(hours: 2)),
          isRead: true,
        ),
      ],
      createdAt: now.subtract(const Duration(days: 2)),
      lastMessageAt: now.subtract(const Duration(hours: 2)),
    );

    final translationDemo = _buildTranslationDemoThread(me);

    return (
      user: me,
      activeThreads: [
        translationDemo.thread,
        bookingThread,
        upcomingThread,
        pendingThread,
        completedThread,
        supportThread,
      ],
      archivedThreads: const [],
      users: {
        ...?users,
        me.id: me,
        mila.id: mila,
        jonas.id: jonas,
        lina.id: lina,
        paula.id: paula,
        translationDemo.other.id: translationDemo.other,
      },
      items: {
        ...?items,
        camera.id: camera,
        cargoBike.id: cargoBike,
        projector.id: projector,
        grill.id: grill,
        translationDemo.item.id: translationDemo.item,
      },
    );
  }

  ({MessageThread thread, User other, Item item}) _buildTranslationDemoThread(User me) {
    final now = DateTime.now();
    final other = User(
      id: 'demo_translation_partner',
      displayName: 'Lucía Ortega',
      email: 'lucia.ortega@example.com',
      preferredLanguage: 'es',
      isVerified: true,
      isBanned: false,
      role: 'user',
      avgRating: 4.7,
      reviewCount: 42,
      createdAt: now.subtract(const Duration(days: 180)),
    );

    final item = Item(
      id: 'demo_translation_item',
      ownerId: other.id,
      title: 'DJI Mini 4 Pro Drohne',
      description: 'Demo-Artikel für Übersetzungs-Tests',
      categoryId: 'electronics',
      subcategory: 'drones',
      tags: const ['drohne', 'camera'],
      pricePerDay: 39,
      currency: 'EUR',
      photos: const [],
      locationText: 'Berlin, Prenzlauer Berg',
      lat: 52.54,
      lng: 13.41,
      geohash: 'u33dc1',
      condition: 'excellent',
      createdAt: now.subtract(const Duration(days: 5)),
      isActive: true,
      verificationStatus: 'verified',
      city: 'Berlin',
      country: 'Deutschland',
    );

    final messages = [
      Message(
        id: 'demo_tr_1',
        senderId: other.id,
        text: 'Hola! Ich schreibe kurz auf Spanisch, damit du die Übersetzung testen kannst.',
        timestamp: now.subtract(const Duration(minutes: 35)),
        isRead: false,
      ),
      Message(
        id: 'demo_tr_2',
        senderId: me.id,
        text: 'Hi Lucía! Ich aktiviere gleich die Übersetzung.',
        timestamp: now.subtract(const Duration(minutes: 33)),
        isRead: true,
      ),
      Message(
        id: 'demo_tr_3',
        senderId: other.id,
        text: 'Could you share the exact pickup spot in English?',
        timestamp: now.subtract(const Duration(minutes: 29)),
        isRead: false,
      ),
      Message(
        id: 'demo_tr_4',
        senderId: me.id,
        text: 'Klar, Treffpunkt ist am Parkeingang Ecke Kastanienallee.',
        timestamp: now.subtract(const Duration(minutes: 27)),
        isRead: true,
      ),
      Message(
        id: 'demo_tr_5',
        senderId: other.id,
        text: 'Perfecto, gracias. ¿Puedes confirmar la hora a las 18:00?',
        timestamp: now.subtract(const Duration(minutes: 24)),
        isRead: false,
      ),
    ];

    final thread = MessageThread(
      id: _translationDemoThreadId,
      requestId: 'demo_translation_request',
      itemId: item.id,
      itemTitle: item.title,
      user1Id: me.id,
      user2Id: other.id,
      bookingStatus: 'running',
      handoverAt: now.add(const Duration(hours: 4)),
      returnAt: now.add(const Duration(days: 2, hours: 4)),
      otherUserOnline: true,
      messages: messages,
      createdAt: now.subtract(const Duration(days: 1)),
      lastMessageAt: messages.last.timestamp,
    );

    return (thread: thread, other: other, item: item);
  }

  ({List<MessageThread> activeThreads, Map<String, User> users, Map<String, Item> items}) _withTranslationDemoThread({
    required User user,
    required List<MessageThread> activeThreads,
    required Map<String, User> users,
    required Map<String, Item> items,
  }) {
    if (!QaRuntimeService.isEnabled) {
      return (activeThreads: activeThreads, users: users, items: items);
    }
    final exists = activeThreads.any((t) => t.id == _translationDemoThreadId);
    if (exists || activeThreads.isNotEmpty) {
      return (activeThreads: activeThreads, users: users, items: items);
    }

    final demo = _buildTranslationDemoThread(user);
    final updatedThreads = [demo.thread, ...activeThreads];
    final updatedUsers = {...users, demo.other.id: demo.other};
    final updatedItems = {...items, demo.item.id: demo.item};
    return (activeThreads: updatedThreads, users: updatedUsers, items: updatedItems);
  }

  bool get _hasUser => _currentUser != null;

  @override
  Widget build(BuildContext context) {
    final threads = _filteredThreads();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        centerTitle: true,
        title: const Text('Nachrichten'),
        actions: [
          IconButton(
            tooltip: _searchVisible ? 'Suche schließen' : 'Suche öffnen',
            onPressed: _toggleSearch,
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
          ),
          IconButton(
            tooltip: 'Nachrichten-Einstellungen',
            onPressed: _openMessageSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _searchVisible
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: _InlineSearchBar(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        hintText: 'Chats, Personen oder Artikel suchen',
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        onClose: _hideSearch,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: _FilterTabs(
                filter: _filter,
                showBlocked: _blockedUserIds.isNotEmpty,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (!_hasUser)
                      ? _EmptyState(
                          config: const _MessagesEmptyStateConfig(
                            title: 'Noch keine Nachrichten',
                            body: 'Deine Gespräche erscheinen hier, sobald du eine Anfrage stellst oder annimmst.',
                            buttonLabel: 'Jetzt entdecken',
                            buttonIcon: Icons.explore,
                          ),
                          onCta: () => Navigator.of(context).maybePop(),
                        )
                      : threads.isEmpty
                          ? _EmptyState(
                              config: _emptyStateConfig(),
                              onCta: _filter == _MessagesFilter.blocked
                                  ? () => openBlockedUsersManagement(context)
                                  : () => Navigator.of(context).maybePop(),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                              itemCount: threads.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final thread = threads[index];
                                final isDemoTranslation = thread.id == _translationDemoThreadId;
                                final other = _otherUser(thread);
                                final lastMsg = thread.messages.isNotEmpty ? thread.messages.last : null;
                                final hasUnread = _hasUnread(thread);
                                final status = _derivedStatus(thread);
                                final highlight = status.rank <= 1; // running/accepted
                                final isTerminal = status.isTerminal;
                                final isSupport = (thread.threadType ?? '').toLowerCase() == 'support' || thread.user1Id == 'support' || thread.user2Id == 'support';
                                final item = _itemsCache[thread.itemId];
                                  return _ThreadDismissible(
                                    enabled: !isDemoTranslation,
                                    dismissKey: ValueKey('thread_${thread.id}_${_filter.name}'),
                                    thread: thread,
                                    onArchiveToggle: () async {
                                      if (_currentUser == null) return;
                                      if (isDemoTranslation) {
                                        if (mounted) AppPopup.toast(context, icon: Icons.visibility_outlined, title: 'Demo-Chat', message: 'Archivieren ist für die Demo deaktiviert.');
                                        return;
                                      }
                                      final isArchived = thread.archivedForUserIds.contains(_currentUser!.id);
                                      if (isArchived) {
                                        await DataService.unarchiveMessageThreadForUser(threadId: thread.id, userId: _currentUser!.id);
                                      } else {
                                        await DataService.archiveMessageThreadForUser(threadId: thread.id, userId: _currentUser!.id);
                                      }
                                      await _loadData();
                                    },
                                    onDelete: () async {
                                      if (isDemoTranslation) {
                                        if (mounted) AppPopup.toast(context, icon: Icons.visibility_outlined, title: 'Demo-Chat', message: 'Löschen ist für die Demo deaktiviert.');
                                        return;
                                      }
                                      final ok = await _confirmDelete();
                                      if (!ok) return;
                                      await DataService.deleteMessageThread(threadId: thread.id);
                                      await _loadData();
                                    },
                                    child: _ChatThreadTile(
                                      name: isSupport ? 'SIT Support' : (other?.displayName ?? 'Unbekannt'),
                                      itemTitle: isSupport ? '' : thread.itemTitle,
                                      itemImageUrl: item?.photos.isNotEmpty == true ? item!.photos.first : null,
                                      avatarUrl: isSupport ? null : other?.photoURL,
                                      isSupport: isSupport,
                                      isVerified: other?.isVerified ?? false,
                                      hasUnread: hasUnread,
                                      timeLabel: _formatTime(lastMsg?.timestamp ?? thread.lastMessageAt ?? thread.createdAt),
                                      statusLabel: status.label,
                                      statusTone: status.tone,
                                      lastMessage: lastMsg?.text ?? '',
                                      showPreview: _messageSettings.showChatPreview,
                                      highlighted: highlight,
                                      muted: _isThreadMuted(thread),
                                      blocked: _isOtherUserBlocked(thread),
                                      onTap: () => _openThread(thread, other),
                                      onLongPress: () => _openThreadOptions(thread),
                                    ),
                                  );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  List<MessageThread> _filteredThreads() {
    final userId = _currentUser?.id;
    if (userId == null) return const [];

    final all = [..._activeThreads, ..._archivedThreads];
    var filtered = all.where((t) {
      final type = (t.threadType ?? '').toLowerCase();
      final isSupport = type == 'support' || t.user1Id == 'support' || t.user2Id == 'support';
      final status = _derivedStatus(t);
      final isArchived = t.archivedForUserIds.contains(userId);
      final isBlocked = _isOtherUserBlocked(t);

      switch (_filter) {
        case _MessagesFilter.all:
          return !isArchived && !isBlocked;
        case _MessagesFilter.bookings:
          return !isSupport && !isArchived && !isBlocked;
        case _MessagesFilter.active:
          return !isSupport && !isArchived && !isBlocked && !status.isTerminal;
        case _MessagesFilter.archived:
          return isArchived && !isBlocked;
        case _MessagesFilter.blocked:
          return isBlocked;
        case _MessagesFilter.support:
          return isSupport && !isArchived && !isBlocked;
      }
    }).toList();

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((t) => _matchesQuery(t, query)).toList();
    }

    filtered.sort((a, b) {
      final ar = _derivedStatus(a).rank;
      final br = _derivedStatus(b).rank;
      if (ar != br) return ar.compareTo(br);
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return filtered;
  }

  bool _matchesQuery(MessageThread thread, String query) {
    final me = _currentUser;
    if (me == null) return false;

    final otherId = thread.user1Id == me.id ? thread.user2Id : thread.user1Id;
    final other = _usersCache[otherId];
    final name = (other?.displayName ?? '').toLowerCase();
    final item = thread.itemTitle.toLowerCase();
    final anyMsg = thread.messages.any((m) => m.text.toLowerCase().contains(query));

    return name.contains(query) || item.contains(query) || anyMsg;
  }

  Map<_MessagesFilter, int> _tabCounts() {
    final userId = _currentUser?.id;
    if (userId == null) return {for (final f in _MessagesFilter.values) f: 0};

    int unreadFor(Iterable<MessageThread> threads) {
      int sum = 0;
      for (final t in threads) {
        if (_hasUnread(t)) sum++;
      }
      return sum;
    }

    bool isSupport(MessageThread t) => (t.threadType ?? '').toLowerCase() == 'support' || t.user1Id == 'support' || t.user2Id == 'support';

    final all = [..._activeThreads, ..._archivedThreads];
    final support = all.where((t) => isSupport(t) && !_isOtherUserBlocked(t) && !t.archivedForUserIds.contains(userId));
    final nonSupport = all.where((t) => !isSupport(t));
    final visibleNonBlocked = nonSupport.where((t) => !_isOtherUserBlocked(t));
    final blocked = nonSupport.where((t) => _isOtherUserBlocked(t));

    final active = visibleNonBlocked.where((t) {
      final st = _derivedStatus(t);
      return !t.archivedForUserIds.contains(userId) && !st.isTerminal;
    });
    final archived = visibleNonBlocked.where((t) => t.archivedForUserIds.contains(userId));
    final allVisible = all.where((t) => !_isOtherUserBlocked(t) && !t.archivedForUserIds.contains(userId));

    return {
      _MessagesFilter.all: unreadFor(allVisible),
      _MessagesFilter.bookings: unreadFor(visibleNonBlocked.where((t) => !t.archivedForUserIds.contains(userId))),
      _MessagesFilter.active: unreadFor(active),
      _MessagesFilter.archived: unreadFor(archived),
      _MessagesFilter.blocked: unreadFor(blocked),
      _MessagesFilter.support: unreadFor(support),
    };
  }

  bool _hasUnread(MessageThread thread) {
    final userId = _currentUser?.id;
    if (userId == null) return false;
    return thread.messages.any((m) => m.senderId != userId && !m.isRead);
  }

  User? _otherUser(MessageThread thread) {
    final me = _currentUser;
    if (me == null) return null;
    final otherUserId = thread.user1Id == me.id ? thread.user2Id : thread.user1Id;
    return _usersCache[otherUserId];
  }


  bool _canBlockThread(MessageThread thread) {
    if (_isOtherUserBlocked(thread)) return true;
    final isSupport = (thread.threadType ?? '').toLowerCase() == 'support' || thread.user1Id == 'support' || thread.user2Id == 'support';
    if (isSupport) return false;
    return _derivedStatus(thread).isTerminal;
  }

  ({String label, _StatusTone tone, int rank, bool isTerminal}) _derivedStatus(MessageThread thread) {
    // Prefer the thread snapshot, because demo threads do not necessarily have a RentalRequest.
    final raw = (thread.bookingStatus ?? '').toLowerCase().trim();
    switch (raw) {
      case 'running':
        return (label: 'Laufend', tone: _StatusTone.success, rank: 0, isTerminal: false);
      case 'accepted':
        return (label: 'Bestätigt', tone: _StatusTone.info, rank: 1, isTerminal: false);
      case 'pending':
        return (label: 'Anfrage offen', tone: _StatusTone.warning, rank: 2, isTerminal: false);
      case 'completed':
        return (label: 'Abgeschlossen', tone: _StatusTone.neutral, rank: 3, isTerminal: true);
      case 'cancelled':
      case 'declined':
        return (label: 'Abgeschlossen', tone: _StatusTone.neutral, rank: 4, isTerminal: true);
      default:
        // Support or generic chat
        final isSupport = (thread.threadType ?? '').toLowerCase() == 'support' || thread.user1Id == 'support' || thread.user2Id == 'support';
        if (isSupport) return (label: 'Support', tone: _StatusTone.info, rank: 0, isTerminal: false);
        return (label: 'Chat', tone: _StatusTone.neutral, rank: 2, isTerminal: false);
    }
  }

  String? _presenceText(MessageThread thread, User? other) {
    final isSupport = (thread.threadType ?? '').toLowerCase() == 'support' || thread.user1Id == 'support' || thread.user2Id == 'support';
    if (isSupport) return 'Online';

    if (thread.otherUserOnline == true) return 'Online';
    final last = thread.otherUserLastActive;
    if (last == null) return null;
    final diff = DateTime.now().difference(last);
    if (diff.inMinutes < 2) return 'Gerade aktiv';
    if (diff.inMinutes < 60) return 'Vor ${diff.inMinutes} Min aktiv';
    if (diff.inHours < 24) return 'Vor ${diff.inHours} Std aktiv';
    return 'Kürzlich aktiv';
  }

  String? _uspLine(MessageThread thread) {
    final now = DateTime.now();
    DateTime? when;
    String? label;

    if (thread.handoverAt != null && thread.handoverAt!.isAfter(now.subtract(const Duration(hours: 12)))) {
      when = thread.handoverAt;
      label = 'Übergabe';
    } else if (thread.returnAt != null && thread.returnAt!.isAfter(now.subtract(const Duration(days: 1)))) {
      when = thread.returnAt;
      label = 'Rückgabe';
    }

    if (when == null || label == null) return null;
    final day = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    final diffDays = day.difference(today).inDays;
    final time = '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    final dayLabel = diffDays == 0 ? 'Heute' : (diffDays == 1 ? 'Morgen' : '${when.day}.${when.month}.');
    return '$label: $dayLabel $time';
  }

  void _toggleSearch() {
    if (!_searchVisible) {
      setState(() => _searchVisible = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
      return;
    }
    _hideSearch();
  }

  void _hideSearch() {
    setState(() {
      _searchVisible = false;
      _searchQuery = '';
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  Future<void> _openThread(MessageThread thread, User? otherUser) async {
    if (thread.id.startsWith('mock_')) {
      if (!mounted) return;
      AppPopup.toast(
        context,
        icon: Icons.visibility_outlined,
        title: 'Demo-Vorschau',
        message: 'Diese Unterhaltung ist nur für die UI-Vorschau eingeblendet.',
      );
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageThreadScreen(
          threadId: thread.id,
          participantName: otherUser?.displayName ?? (thread.threadType == 'support' ? 'SIT Support' : 'Unbekannt'),
          avatarUrl: otherUser?.photoURL,
          itemTitle: thread.threadType == 'support' ? 'Support' : thread.itemTitle,
        ),
      ),
    );
    if (result == true) {
      await _loadData();
    } else {
      // Also refresh because reading a thread toggles unread state.
      await _loadData();
    }
  }

  Future<void> _openThreadOptions(MessageThread thread) async {
    final userId = _currentUser?.id;
    if (userId == null) return;
    if (thread.id == _translationDemoThreadId || thread.id.startsWith('mock_')) {
      if (mounted) {
        AppPopup.toast(context, icon: Icons.visibility_outlined, title: 'Demo-Chat', message: 'Verwalten ist für die Demo deaktiviert.');
      }
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      backgroundColor: Colors.transparent,
      builder: (context) => _ThreadOptionsSheet(isArchived: thread.archivedForUserIds.contains(userId), hasUnread: _hasUnread(thread), canBlock: _canBlockThread(thread), isBlocked: _isOtherUserBlocked(thread)),
    );
    if (choice == null) return;

    switch (choice) {
      case 'read':
        await DataService.markThreadMessagesAsRead(threadId: thread.id, userId: userId);
        break;
      case 'archive':
        await DataService.archiveMessageThreadForUser(threadId: thread.id, userId: userId);
        break;
      case 'unarchive':
        await DataService.unarchiveMessageThreadForUser(threadId: thread.id, userId: userId);
        break;
      case 'delete':
        final ok = await _confirmDelete();
        if (!ok) return;
        await DataService.deleteMessageThread(threadId: thread.id);
        break;
      case 'block':
        final otherUserId = thread.user1Id == userId ? thread.user2Id : thread.user1Id;
        if (otherUserId.isEmpty || otherUserId == 'support') {
          if (mounted) {
            AppPopup.toast(context, icon: Icons.info_outline, title: 'Kann Support nicht blockieren');
          }
          return;
        }
        final isBlocked = _isOtherUserBlocked(thread);
        if (!isBlocked && !_canBlockThread(thread)) {
          if (mounted) {
            AppPopup.toast(context, icon: Icons.info_outline, title: 'Blockieren erst nach abgeschlossener Buchung möglich');
          }
          return;
        }
        if (isBlocked) {
          await BlockedUsersService.unblockUser(otherUserId);
          if (mounted) {
            AppPopup.toast(context, icon: Icons.lock_open_outlined, title: 'Blockierung aufgehoben');
          }
        } else {
          await BlockedUsersService.blockUser(otherUserId);
          await DataService.archiveMessageThreadForUser(threadId: thread.id, userId: userId);
          debugPrint('[Messages] User $otherUserId blocked and thread ${thread.id} archived');
          if (mounted) {
            AppPopup.toast(context, icon: Icons.block, title: 'Nutzer blockiert', message: 'Du erhältst keine Nachrichten mehr von dieser Person.');
          }
        }
        break;
    }
    await _loadData();
  }

  Future<bool> _confirmDelete() async {
    return (await showModalBottomSheet<bool>(
          context: context,
          useRootNavigator: true,
          barrierColor: Colors.black.withValues(alpha: 0.45),
          backgroundColor: Colors.transparent,
          builder: (context) => const _ConfirmDeleteSheet(),
        )) ??
        false;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Gestern';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}.${time.month}.';
  }

  Future<void> _openMessageSettings() async {
    debugPrint('[MessagesScreen] open settings tapped');
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const MessagesSettingsScreen()));
    if (result == true) {
      await _loadData();
      if (!mounted) return;
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Änderungen wurden gespeichert.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white : AppTheme.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            duration: const Duration(milliseconds: 2500),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
            ),
          ),
        );
    }
  }
}

class _InlineSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final String hintText;
  const _InlineSearchBar({required this.controller, required this.focusNode, required this.onChanged, required this.onClose, required this.hintText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surface;
    final overlay = theme.brightness == Brightness.dark ? baseColor.withValues(alpha: 0.24) : baseColor.withValues(alpha: 0.92);
    final border = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: overlay,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
              prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (controller.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), size: 18),
                  ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.keyboard_hide, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), size: 18),
                ),
              ]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final _MessagesFilter filter;
  final bool showBlocked;
  final ValueChanged<_MessagesFilter> onChanged;
  const _FilterTabs({required this.filter, required this.showBlocked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(children: [
        _FilterPill(label: 'Aktiv', selected: filter == _MessagesFilter.active, onTap: () => onChanged(_MessagesFilter.active)),
        const SizedBox(width: 10),
        _FilterPill(label: 'Alle', selected: filter == _MessagesFilter.all, onTap: () => onChanged(_MessagesFilter.all)),
        const SizedBox(width: 10),
        _FilterPill(label: 'Archiv', selected: filter == _MessagesFilter.archived, onTap: () => onChanged(_MessagesFilter.archived)),
        const SizedBox(width: 10),
        _FilterPill(label: 'Support', selected: filter == _MessagesFilter.support, onTap: () => onChanged(_MessagesFilter.support)),
        if (showBlocked) ...[
          const SizedBox(width: 10),
          _FilterPill(label: 'Blockiert', selected: filter == _MessagesFilter.blocked, onTap: () => onChanged(_MessagesFilter.blocked)),
        ],
      ]),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = selected
        ? Theme.of(context).colorScheme.primary
        : (isDark ? AppTheme.surfaceSecondary(context) : const Color(0xFFF8FAFC));
    final border = isDark ? AppTheme.glassStroke(context) : const Color(0xFFE2E8F0);
    final text = selected ? Colors.white : AppTheme.textBody(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: text,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StatusTone { neutral, info, warning, success }

class _ChatThreadTile extends StatelessWidget {
  final String name;
  final String itemTitle;
  final String? itemImageUrl;
  final String lastMessage;
  final bool showPreview;
  final String timeLabel;
  final String? avatarUrl;
  final bool isSupport;
  final bool isVerified;
  final bool hasUnread;
  final String statusLabel;
  final _StatusTone statusTone;
  final bool highlighted;
  final bool muted;
  final bool blocked;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatThreadTile({
    required this.name,
    required this.itemTitle,
    this.itemImageUrl,
    required this.avatarUrl,
    this.isSupport = false,
    this.isVerified = false,
    required this.hasUnread,
    required this.timeLabel,
    required this.statusLabel,
    required this.statusTone,
    required this.lastMessage,
    this.showPreview = true,
    required this.highlighted,
    this.muted = false,
    this.blocked = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrlTrimmed = (avatarUrl ?? '').trim();
    final hasAvatar = avatarUrlTrimmed.isNotEmpty && !isSupport;
    final hasItemImage = (itemImageUrl ?? '').trim().isNotEmpty;

    final ColorFilter? grayscaleFilter = muted
        ? const ColorFilter.matrix([
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ])
        : null;

    Color statusColor;
    switch (statusTone) {
      case _StatusTone.success:
        statusColor = BrandColors.success;
        break;
      case _StatusTone.warning:
        statusColor = Colors.amber.shade300;
        break;
      case _StatusTone.info:
        statusColor = BrandColors.primary;
        break;
      case _StatusTone.neutral:
        statusColor = Colors.grey;
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.glassStroke(context) : const Color(0xFFE2E8F0);
    final bg = isDark ? (highlighted ? AppTheme.surfaceSecondary(context) : AppTheme.surfaceMuted(context)) : Colors.white;
    final glow = const <BoxShadow>[];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: border), boxShadow: glow),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Linkes Bild: Item-Bild quadratisch mit User-Avatar überlagert
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    grayscaleFilter == null
                        ? (isSupport
                            ? _SupportAvatar(size: 48)
                            : _ItemImageTile(imageUrl: hasItemImage ? itemImageUrl : null, size: 48))
                        : ColorFiltered(
                            colorFilter: grayscaleFilter,
                            child: isSupport
                                ? _SupportAvatar(size: 48)
                                : _ItemImageTile(imageUrl: hasItemImage ? itemImageUrl : null, size: 48),
                          ),
                    // Rundes User-Profilbild rechts unten überlagert
                    if (!isSupport)
                      Positioned(
                        right: -4,
                        bottom: -10,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.surfacePrimary(context), width: 2),
                          ),
                          child: grayscaleFilter == null
                              ? SitUserAvatar(
                                  url: hasAvatar ? avatarUrlTrimmed : null,
                                  radius: 15,
                                  borderColor: Colors.transparent,
                                  placeholderIcon: Icons.person,
                                )
                              : ColorFiltered(
                                  colorFilter: grayscaleFilter,
                                  child: SitUserAvatar(
                                    url: hasAvatar ? avatarUrlTrimmed : null,
                                    radius: 15,
                                    borderColor: Colors.transparent,
                                    placeholderIcon: Icons.person,
                                  ),
                                ),
                        ),
                      ),
                    // Ungelesen-Badge
                    if (hasUnread)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: BrandColors.logoAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                // Mittlerer Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Zeile 1: Name + Verifiziert-Icon (links), Uhrzeit + Status-Chip (rechts)
                      Row(children: [
                        // Name + Verifiziert-Icon
                        Expanded(
                          child: Row(children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppTheme.textPrimary(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      height: 22/16,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Verifiziert-Symbol (nicht bei Support)
                            if (!isSupport)
                              Icon(
                                Icons.verified,
                                size: 14,
                                color: isVerified ? BrandColors.success : (isDark ? Colors.grey.withValues(alpha: 0.5) : const Color(0xFF475569)),
                              ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        // Status-Chip + Uhrzeit (rechts ausgerichtet)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          // Status-Chip nur bei Nicht-Support
                          if (!isSupport) ...[
                            _StatusChip(label: statusLabel, color: statusColor),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            timeLabel,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textSecondary(context),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                  height: 16/12,
                                ),
                          ),
                        ]),
                      ]),
                      // Zeile 2: Item-Titel mit Punkt davor (nur wenn vorhanden)
                      if (itemTitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '· $itemTitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textBody(context),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                height: 20/14,
                              ),
                        ),
                      ],
                      if (muted || blocked) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (muted)
                              const _ThreadStateChip(icon: Icons.notifications_off_outlined, label: 'Stumm'),
                            if (blocked)
                              const _ThreadStateChip(icon: Icons.block_outlined, label: 'Blockiert', danger: true),
                          ],
                        ),
                      ],
                      if (showPreview) ...[
                        const SizedBox(height: 3),
                        Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary(context),
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                height: 20/14,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: AppTheme.textDisabled(context), size: 16),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}


class _ThreadStateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  const _ThreadStateChip({required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = danger ? Colors.red.shade300 : (isDark ? AppTheme.textSecondary(context) : const Color(0xFF1E293B));
    final bg = danger ? Colors.red.withValues(alpha: 0.12) : (isDark ? AppTheme.surfaceMuted(context) : const Color(0xFFE2E8F0));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Quadratisches Item-Bild für Chat-Card
class _ItemImageTile extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const _ItemImageTile({this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    final hasImage = url.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: AppTheme.surfaceMuted(context),
        child: hasImage
            ? Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Center(
        child: Icon(Icons.image_outlined, color: AppTheme.textDisabled(context), size: 22),
      );
}

/// SIT-Logo als Avatar für Support-Chats (rund)
class _SupportAvatar extends StatelessWidget {
  final double size;
  const _SupportAvatar({this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BrandColors.primary.withValues(alpha: 0.18),
        border: Border.all(color: BrandColors.primary.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipOval(
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, 2.1), // 0.8mm nach unten für optische Zentrierung
            child: Image.asset(
              'assets/images/icononly_transparent_nobuffer.png',
              width: size * 0.8,
              height: size * 0.8,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.support_agent_rounded,
                color: AppTheme.textPrimary(context),
                size: size * 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 12, height: 16/12)),
    );
  }
}

class _ThreadDismissible extends StatelessWidget {
  final Key dismissKey;
  final MessageThread thread;
  final Widget child;
  final Future<void> Function() onArchiveToggle;
  final Future<void> Function() onDelete;
  final bool enabled;

  const _ThreadDismissible({
    required this.dismissKey,
    required this.thread,
    required this.child,
    required this.onArchiveToggle,
    required this.onDelete,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: _SwipeActionsBackground(onArchive: () {}, onDelete: () {}),
      confirmDismiss: (dir) async {
        // Instead of auto-action, open a quick action sheet (more trust-focused).
        final choice = await showModalBottomSheet<String>(
          context: context,
          useRootNavigator: true,
          barrierColor: Colors.black.withValues(alpha: 0.35),
          backgroundColor: Colors.transparent,
          builder: (context) => const _SwipeActionSheet(),
        );
        if (choice == 'archive') {
          await onArchiveToggle();
        } else if (choice == 'delete') {
          await onDelete();
        }
        return false;
      },
      child: child,
    );
  }
}

class _SwipeActionsBackground extends StatelessWidget {
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  const _SwipeActionsBackground({required this.onArchive, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        _SwipeActionPill(icon: Icons.archive_outlined, label: 'Archivieren', color: BrandColors.primary, onTap: onArchive),
        const SizedBox(width: 10),
        _SwipeActionPill(icon: Icons.delete_outline, label: 'Löschen', color: BrandColors.danger, onTap: onDelete),
      ]),
    );
  }
}

class _SwipeActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SwipeActionPill({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: AppTheme.textPrimary(context)),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textPrimary(context), fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

class _SwipeActionSheet extends StatelessWidget {
  const _SwipeActionSheet();

  @override
  Widget build(BuildContext context) {
    return _GlassSheet(
      title: 'Chat verwalten',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetAction(
            icon: Icons.archive_outlined,
            title: 'Archivieren',
            subtitle: 'Du findest den Chat später im Archiv.',
            onTap: () => Navigator.of(context).pop('archive'),
          ),
          const SizedBox(height: 10),
          _SheetAction(
            icon: Icons.delete_outline,
            title: 'Löschen',
            subtitle: 'Entfernt den Chat dauerhaft (lokal).',
            danger: true,
            onTap: () => Navigator.of(context).pop('delete'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        ],
      ),
    );
  }
}

class _ThreadOptionsSheet extends StatelessWidget {
  final bool isArchived;
  final bool hasUnread;
  final bool canBlock;
  final bool isBlocked;
  const _ThreadOptionsSheet({required this.isArchived, required this.hasUnread, required this.canBlock, required this.isBlocked});

  @override
  Widget build(BuildContext context) {
    return _GlassSheet(
      title: 'Optionen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasUnread) ...[
            _SheetAction(
              icon: Icons.mark_email_read_outlined,
              title: 'Als gelesen markieren',
              subtitle: 'Entfernt den ungelesen Badge.',
              onTap: () => Navigator.of(context).pop('read'),
            ),
            const SizedBox(height: 10),
          ],
          _SheetAction(
            icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
            title: isArchived ? 'Aus Archiv holen' : 'Archivieren',
            subtitle: isArchived ? 'Chat erscheint wieder unter „Alle“. ' : 'Chat erscheint unter „Archiv“.',
            onTap: () => Navigator.of(context).pop(isArchived ? 'unarchive' : 'archive'),
          ),
          const SizedBox(height: 10),
          if (canBlock || isBlocked)
            _SheetAction(
              icon: isBlocked ? Icons.lock_open_outlined : Icons.block,
              title: isBlocked ? 'Blockierung aufheben' : 'Blockieren',
              subtitle: isBlocked ? 'Der Nutzer kann wieder normal kontaktiert werden.' : 'Nur nach abgeschlossener Buchung möglich.',
              danger: !isBlocked,
              onTap: () => Navigator.of(context).pop('block'),
            ),
          const SizedBox(height: 10),
          _SheetAction(
            icon: Icons.delete_outline,
            title: 'Löschen',
            subtitle: 'Entfernt den Chat dauerhaft (lokal).',
            danger: true,
            onTap: () => Navigator.of(context).pop('delete'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen')),
        ],
      ),
    );
  }
}

class _ConfirmDeleteSheet extends StatelessWidget {
  const _ConfirmDeleteSheet();

  @override
  Widget build(BuildContext context) {
    return _GlassSheet(
      title: 'Chat löschen?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Diese Aktion kann nicht rückgängig gemacht werden.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textBody(context), height: 1.45, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen'))),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: BrandColors.danger),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Löschen'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _GlassSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              decoration: BoxDecoration(
                color: AppTheme.surfacePrimary(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.glassStroke(context)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: 44,
                  child: Stack(children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textDisabled(context), borderRadius: BorderRadius.circular(2)))),
                    Positioned.fill(
                      child: Center(
                        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary(context), fontWeight: FontWeight.w900)),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.of(context).pop(),
                        child: SizedBox(width: 44, height: 44, child: Center(child: Icon(Icons.close, color: AppTheme.textPrimary(context)))),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                child,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;
  final VoidCallback onTap;
  const _SheetAction({required this.icon, required this.title, required this.subtitle, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = danger ? BrandColors.danger : AppTheme.textPrimary(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSecondary(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.glassStroke(context)),
          ),
          child: Row(children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: c, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary(context), height: 1.35, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MessagesEmptyStateConfig {
  final String title;
  final String body;
  final String buttonLabel;
  final IconData buttonIcon;

  const _MessagesEmptyStateConfig({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.buttonIcon,
  });
}

class _EmptyState extends StatelessWidget {
  final _MessagesEmptyStateConfig config;
  final VoidCallback onCta;
  const _EmptyState({required this.config, required this.onCta});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(config.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textPrimary(context), fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            config.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textBody(context), height: 1.45, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: onCta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(config.buttonIcon, color: Colors.black),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          config.buttonLabel,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
