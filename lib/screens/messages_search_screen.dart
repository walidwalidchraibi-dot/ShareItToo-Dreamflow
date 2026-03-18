import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lendify/models/message.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/screens/message_thread_screen.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/user_avatar.dart';

/// Dedicated search page for Messages.
///
/// This screen does not inline-filter the MessagesScreen list – it provides a
/// focused “hub” search for threads by person, item title, and message text.
class MessagesSearchScreen extends StatefulWidget {
  final User? currentUser;
  final List<MessageThread> threads;
  final Map<String, User> usersById;

  const MessagesSearchScreen({
    super.key,
    required this.currentUser,
    required this.threads,
    required this.usersById,
  });

  @override
  State<MessagesSearchScreen> createState() => _MessagesSearchScreenState();
}

class _MessagesSearchScreenState extends State<MessagesSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: const Text('Suche'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: 'Nachrichten, Personen oder Artikel suchen',
                        hintStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close, color: Colors.white70),
                              ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.02),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _query.isEmpty ? 'Tippe, um Chats zu durchsuchen.' : 'Keine Treffer gefunden.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final r = results[index];
                        return _SearchResultCard(
                          title: r.title,
                          subtitle: r.subtitle,
                          avatarUrl: r.avatarUrl,
                          onTap: () => _openThread(r.thread),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_SearchHit> _filtered() {
    final me = widget.currentUser;
    if (me == null) return const [];
    final q = _query.toLowerCase();

    bool matchesThread(MessageThread t) {
      if (q.isEmpty) return true;
      final otherId = t.user1Id == me.id ? t.user2Id : t.user1Id;
      final other = widget.usersById[otherId];
      final name = (other?.displayName ?? '').toLowerCase();
      final item = (t.itemTitle).toLowerCase();
      final anyMsg = t.messages.any((m) => m.text.toLowerCase().contains(q));
      return name.contains(q) || item.contains(q) || anyMsg;
    }

    final hits = <_SearchHit>[];
    for (final t in widget.threads) {
      if (!matchesThread(t)) continue;
      final otherId = t.user1Id == me.id ? t.user2Id : t.user1Id;
      final other = widget.usersById[otherId];
      final last = t.messages.isNotEmpty ? t.messages.last.text.trim() : '';
      final title = other?.displayName ?? ((t.threadType ?? '').toLowerCase() == 'support' ? 'SIT Support' : 'Unbekannt');
      final subtitle = last.isNotEmpty ? '${t.itemTitle} • $last' : t.itemTitle;
      hits.add(_SearchHit(thread: t, title: title, subtitle: subtitle, avatarUrl: other?.photoURL));
    }

    hits.sort((a, b) {
      final at = a.thread.lastMessageAt ?? a.thread.createdAt;
      final bt = b.thread.lastMessageAt ?? b.thread.createdAt;
      return bt.compareTo(at);
    });
    return hits;
  }

  Future<void> _openThread(MessageThread thread) async {
    final me = widget.currentUser;
    if (me == null) return;

    final otherId = thread.user1Id == me.id ? thread.user2Id : thread.user1Id;
    final other = widget.usersById[otherId];

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MessageThreadScreen(
            threadId: thread.id,
            participantName: other?.displayName ?? ((thread.threadType ?? '').toLowerCase() == 'support' ? 'SIT Support' : 'Unbekannt'),
            avatarUrl: other?.photoURL,
            itemTitle: (thread.threadType ?? '').toLowerCase() == 'support' ? 'Support' : thread.itemTitle,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[MessagesSearch] open thread failed: $e');
    }
  }
}

class _SearchHit {
  final MessageThread thread;
  final String title;
  final String subtitle;
  final String? avatarUrl;
  const _SearchHit({required this.thread, required this.title, required this.subtitle, required this.avatarUrl});
}

class _SearchResultCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onTap;
  const _SearchResultCard({required this.title, required this.subtitle, required this.avatarUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = (avatarUrl ?? '').trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  SitUserAvatar(url: url.isNotEmpty ? url : null, radius: 22, borderColor: Colors.white.withValues(alpha: 0.14), placeholderIcon: Icons.person_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.white38),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
