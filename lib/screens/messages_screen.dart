import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lendify/models/message.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/screens/messages_search_screen.dart';
import 'package:lendify/screens/messages_settings_screen.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/user_avatar.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

enum _MessagesFilter { all, bookings, active, archived, support }

class _MessagesScreenState extends State<MessagesScreen> {
  _MessagesFilter _filter = _MessagesFilter.all;
  List<MessageThread> _activeThreads = [];
  List<MessageThread> _archivedThreads = [];
  User? _currentUser;
  Map<String, User> _usersCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await DataService.getCurrentUser();
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final threads = await DataService.getMessageThreadsForUser(user.id);
      final archived = await DataService.getArchivedMessageThreadsForUser(user.id);
      final users = await DataService.getUsers();

      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _activeThreads = threads;
        _archivedThreads = archived;
        _usersCache = {for (final u in users) u.id: u};
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('MessagesScreen._loadData failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _hasUser => _currentUser != null;

  @override
  Widget build(BuildContext context) {
    final threads = _filteredThreads();
    final counts = _tabCounts();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: const Text('Nachrichten'),
        actions: [
          IconButton(onPressed: _openSearch, icon: const Icon(Icons.search)),
          IconButton(onPressed: _openMessageSettings, icon: const Icon(Icons.settings)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: _MessagesSearchBar(onTap: _openSearch),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _FilterTabs(
                filter: _filter,
                counts: counts,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (!_hasUser)
                      ? _EmptyState(onCta: () => Navigator.of(context).maybePop())
                      : threads.isEmpty
                          ? _EmptyState(onCta: () => Navigator.of(context).maybePop())
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                              itemCount: threads.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final thread = threads[index];
                                final other = _otherUser(thread);
                                final lastMsg = thread.messages.isNotEmpty ? thread.messages.last : null;
                                final hasUnread = _hasUnread(thread);
                                final status = _derivedStatus(thread);
                                final presence = _presenceText(thread, other);
                                final uspLine = _uspLine(thread);
                                final highlight = status.rank <= 1; // running/accepted
                                return _ThreadDismissible(
                                  dismissKey: ValueKey('thread_${thread.id}_${_filter.name}'),
                                  thread: thread,
                                  onArchiveToggle: () async {
                                    if (_currentUser == null) return;
                                    final isArchived = thread.archivedForUserIds.contains(_currentUser!.id);
                                    if (isArchived) {
                                      await DataService.unarchiveMessageThreadForUser(threadId: thread.id, userId: _currentUser!.id);
                                    } else {
                                      await DataService.archiveMessageThreadForUser(threadId: thread.id, userId: _currentUser!.id);
                                    }
                                    await _loadData();
                                  },
                                  onDelete: () async {
                                    final ok = await _confirmDelete();
                                    if (!ok) return;
                                    await DataService.deleteMessageThread(threadId: thread.id);
                                    await _loadData();
                                  },
                                  child: _ChatThreadTile(
                                    name: other?.displayName ?? (thread.threadType == 'support' ? 'SIT Support' : 'Unbekannt'),
                                    itemTitle: thread.threadType == 'support' ? 'Support' : thread.itemTitle,
                                    avatarUrl: other?.photoURL,
                                    hasUnread: hasUnread,
                                    timeLabel: _formatTime(lastMsg?.timestamp ?? thread.lastMessageAt ?? thread.createdAt),
                                    statusLabel: status.label,
                                    statusTone: status.tone,
                                    lastMessage: lastMsg?.text ?? '',
                                    presenceText: presence,
                                    uspLine: uspLine,
                                    highlighted: highlight,
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
    final filtered = all.where((t) {
      final type = (t.threadType ?? '').toLowerCase();
      final isSupport = type == 'support' || t.user1Id == 'support' || t.user2Id == 'support';
      final status = _derivedStatus(t);
      final isArchived = t.archivedForUserIds.contains(userId);

      switch (_filter) {
        case _MessagesFilter.all:
          return true;
        case _MessagesFilter.bookings:
          return !isSupport;
        case _MessagesFilter.active:
          return !isSupport && !isArchived && !status.isTerminal;
        case _MessagesFilter.archived:
          return isArchived || status.isTerminal;
        case _MessagesFilter.support:
          return isSupport;
      }
    }).toList();

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
    final support = all.where(isSupport);
    final nonSupport = all.where((t) => !isSupport(t));

    final active = nonSupport.where((t) {
      final st = _derivedStatus(t);
      return !t.archivedForUserIds.contains(userId) && !st.isTerminal;
    });
    final archived = nonSupport.where((t) => t.archivedForUserIds.contains(userId) || _derivedStatus(t).isTerminal);

    return {
      _MessagesFilter.all: unreadFor(all),
      _MessagesFilter.bookings: unreadFor(nonSupport),
      _MessagesFilter.active: unreadFor(active),
      _MessagesFilter.archived: unreadFor(archived),
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

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesSearchScreen(
          currentUser: _currentUser,
          threads: [..._activeThreads, ..._archivedThreads],
          usersById: _usersCache,
        ),
      ),
    );
  }

  Future<void> _openThread(MessageThread thread, User? otherUser) async {
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

    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      backgroundColor: Colors.transparent,
      builder: (context) => _ThreadOptionsSheet(isArchived: thread.archivedForUserIds.contains(userId), hasUnread: _hasUnread(thread)),
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
        // Local-only stub: we just toast via debugPrint for now.
        debugPrint('[Messages] block user requested for thread ${thread.id}');
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

  void _openMessageSettings() {
    debugPrint('[MessagesScreen] open settings tapped');
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesSettingsScreen()));
  }
}

class _MessagesSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _MessagesSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.search, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nachrichten, Personen oder Artikel suchen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final _MessagesFilter filter;
  final Map<_MessagesFilter, int> counts;
  final ValueChanged<_MessagesFilter> onChanged;
  const _FilterTabs({required this.filter, required this.counts, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(children: [
        _FilterPill(label: 'Alle', count: counts[_MessagesFilter.all] ?? 0, selected: filter == _MessagesFilter.all, onTap: () => onChanged(_MessagesFilter.all)),
        const SizedBox(width: 8),
        _FilterPill(label: 'Buchungen', count: counts[_MessagesFilter.bookings] ?? 0, selected: filter == _MessagesFilter.bookings, onTap: () => onChanged(_MessagesFilter.bookings)),
        const SizedBox(width: 8),
        _FilterPill(label: 'Aktiv', count: counts[_MessagesFilter.active] ?? 0, selected: filter == _MessagesFilter.active, onTap: () => onChanged(_MessagesFilter.active)),
        const SizedBox(width: 8),
        _FilterPill(label: 'Archiv', count: counts[_MessagesFilter.archived] ?? 0, selected: filter == _MessagesFilter.archived, onTap: () => onChanged(_MessagesFilter.archived)),
        const SizedBox(width: 8),
        _FilterPill(label: 'Support', count: counts[_MessagesFilter.support] ?? 0, selected: filter == _MessagesFilter.support, onTap: () => onChanged(_MessagesFilter.support)),
      ]),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.06);
    final border = selected ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.12);
    final text = selected ? Colors.white : Colors.white70;
    final glow = selected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: glow ? [BoxShadow(color: BrandColors.primary.withValues(alpha: 0.22), blurRadius: 18, spreadRadius: 0)] : const [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: text, fontWeight: selected ? FontWeight.w800 : FontWeight.w700),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              _UnreadBadge(count: count, emphasized: selected),
            ],
          ]),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  final bool emphasized;
  const _UnreadBadge({required this.count, required this.emphasized});

  @override
  Widget build(BuildContext context) {
    final bg = emphasized ? BrandColors.logoAccent : Colors.white.withValues(alpha: 0.14);
    final fg = emphasized ? Colors.black : Colors.white;
    final text = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w900)),
    );
  }
}

enum _StatusTone { neutral, info, warning, success }

class _ChatThreadTile extends StatelessWidget {
  final String name;
  final String itemTitle;
  final String lastMessage;
  final String timeLabel;
  final String? avatarUrl;
  final bool hasUnread;
  final String statusLabel;
  final _StatusTone statusTone;
  final String? presenceText;
  final String? uspLine;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatThreadTile({
    required this.name,
    required this.itemTitle,
    required this.avatarUrl,
    required this.hasUnread,
    required this.timeLabel,
    required this.statusLabel,
    required this.statusTone,
    required this.lastMessage,
    required this.presenceText,
    required this.uspLine,
    required this.highlighted,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final url = (avatarUrl ?? '').trim();
    final hasAvatar = url.isNotEmpty;

    Color statusColor;
    switch (statusTone) {
      case _StatusTone.success:
        statusColor = BrandColors.success;
        break;
      case _StatusTone.warning:
        statusColor = BrandColors.logoAccent;
        break;
      case _StatusTone.info:
        statusColor = BrandColors.primary;
        break;
      case _StatusTone.neutral:
        statusColor = Colors.white70;
        break;
    }

    final border = highlighted ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.10);
    final bg = highlighted ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.22);
    final glow = highlighted ? <BoxShadow>[BoxShadow(color: BrandColors.primary.withValues(alpha: 0.18), blurRadius: 22, spreadRadius: 0)] : const <BoxShadow>[];

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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SitUserAvatar(
                        url: hasAvatar ? url : null,
                        radius: 28,
                        borderColor: Colors.white.withValues(alpha: 0.14),
                        placeholderIcon: Icons.person_outline,
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: presenceText == 'Online' ? BrandColors.success : Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 2),
                          ),
                        ),
                      ),
                      if (hasUnread)
                        const Positioned(
                          right: -2,
                          top: -2,
                          child: DecoratedBox(decoration: BoxDecoration(color: BrandColors.logoAccent, shape: BoxShape.circle), child: SizedBox(width: 10, height: 10)),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                              children: [
                                TextSpan(text: name),
                                TextSpan(
                                  text: ' • $itemTitle',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(timeLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusChip(label: statusLabel, color: statusColor),
                          if (presenceText != null)
                            Text(presenceText!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white60, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35, fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600),
                      ),
                      if (uspLine != null) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Icon(Icons.event_available, size: 16, color: BrandColors.primary.withValues(alpha: 0.9)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              uspLine!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ]),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.chevron_right, color: Colors.white38),
                  ),
                ]),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}

class _ThreadDismissible extends StatelessWidget {
  final Key dismissKey;
  final MessageThread thread;
  final Widget child;
  final Future<void> Function() onArchiveToggle;
  final Future<void> Function() onDelete;

  const _ThreadDismissible({
    required this.dismissKey,
    required this.thread,
    required this.child,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
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
  const _ThreadOptionsSheet({required this.isArchived, required this.hasUnread});

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
          _SheetAction(
            icon: Icons.block,
            title: 'Blockieren',
            subtitle: 'Du erhältst keine Nachrichten mehr von dieser Person.',
            danger: true,
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
            'Diese Aktion kann nicht rückgängig gemacht werden. (Lokale Demo-Daten)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.45, fontWeight: FontWeight.w600),
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
                color: Colors.black.withValues(alpha: 0.46),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: 44,
                  child: Stack(children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(2)))),
                    Positioned.fill(
                      child: Center(
                        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox(width: 44, height: 44, child: Center(child: Icon(Icons.close, color: Colors.white))),
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
    final c = danger ? BrandColors.danger : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: c, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCta;
  const _EmptyState({required this.onCta});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Noch keine Nachrichten', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            'Deine Gespräche erscheinen hier, sobald du eine Anfrage stellst oder annimmst.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.45, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 220,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onCta,
              icon: const Icon(Icons.explore, color: Colors.black),
              label: const Text('Jetzt entdecken', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(backgroundColor: BrandColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      ),
    );
  }
}

