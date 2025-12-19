import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lendify/screens/message_thread_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _selectedFilter = 'Alle';
  String _query = '';
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threads = _filteredThreads();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: const Text('Nachrichten'),
        actions: [
          IconButton(
            onPressed: () {
              // Focus inline search field instead of navigating away
              _searchFocus.requestFocus();
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: _openMessageSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(children: [
        // Inline search card under the title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
            child: TextField(
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nachrichten suchen …',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.02),
              ),
            ),
          ),
        ),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['Alle', 'Buchungen', 'Support'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  selectedColor: Colors.white.withValues(alpha: 0.20),
                  labelStyle: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final thread = threads[index];
              return _ChatThreadCard(
                name: thread['name'],
                lastMessage: thread['lastMessage'],
                time: thread['time'],
                avatarUrl: thread['avatar'],
                hasUnread: thread['hasUnread'],
                bookingStatus: thread['bookingStatus'],
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessageThreadScreen(participantName: thread['name'], avatarUrl: thread['avatar']))),
              );
            },
          ),
        ),
      ]),
    );
  }

  List<Map<String, dynamic>> _filteredThreads() {
    final q = _query.toLowerCase();
    Iterable<Map<String, dynamic>> data = _sampleThreads;
    if (_selectedFilter == 'Support') {
      data = data.where((t) => t['type'] == 'support');
    } else if (_selectedFilter == 'Buchungen') {
      data = data.where((t) => t['type'] == 'booking');
    }
    if (q.isNotEmpty) {
      data = data.where((t) => (t['name'] as String).toLowerCase().contains(q) || (t['lastMessage'] as String).toLowerCase().contains(q));
    }
    return data.toList();
  }

  void _openMessageSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(children: [
                Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: Container(color: Colors.transparent))),
                Align(alignment: Alignment.bottomCenter, child: _MessageSettingsSheet()),
              ]),
            ),
          ),
        );
      },
    );
  }

  static final List<Map<String, dynamic>> _sampleThreads = [
    {
      'name': 'Max Mustermann',
      'lastMessage': 'Danke für die schnelle Antwort!',
      'time': '14.8.',
      'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
      'hasUnread': true,
      'bookingStatus': 'Bestätigt',
      'type': 'booking',
    },
    {
      'name': 'Support Team',
      'lastMessage': 'Wie können wir dir helfen? Antwort innerhalb von 24h.',
      'time': 'Gestern',
      'avatar': 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150&h=150&fit=crop&crop=face',
      'hasUnread': false,
      'bookingStatus': null,
      'type': 'support',
    },
    {
      'name': 'Sarah Schmidt',
      'lastMessage': 'Wann kann ich die Kamera abholen?',
      'time': '13.8.',
      'avatar': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
      'hasUnread': false,
      'bookingStatus': 'Bezahlt',
      'type': 'booking',
    },
    {
      'name': 'Thomas Weber',
      'lastMessage': 'Alles klar, bis morgen!',
      'time': '12.8.',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
      'hasUnread': false,
      'bookingStatus': null,
      'type': 'general',
    },
  ];
}

class _MessageSettingsSheet extends StatefulWidget {
  @override
  State<_MessageSettingsSheet> createState() => _MessageSettingsSheetState();
}

class _MessageSettingsSheetState extends State<_MessageSettingsSheet> {
  bool _muteAll = false;
  bool _readReceipts = true;
  bool _archiveAuto = false;
  @override
  Widget build(BuildContext context) {
    final sheet = Container(
      constraints: const BoxConstraints(maxWidth: 720),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 44,
              child: Stack(children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)))),
                const Positioned.fill(child: Center(child: Text('Nachrichten-Einstellungen', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)))),
                Positioned(right: 16, top: 0, bottom: 0, child: SizedBox(width: 44, height: 44, child: InkWell(borderRadius: BorderRadius.circular(22), onTap: () => Navigator.of(context).maybePop(), child: const Center(child: Icon(Icons.close, color: Colors.white)))))
              ]),
            ),
            const SizedBox(height: 12),
            _SettingsTile(title: 'Alle stummschalten', value: _muteAll, onChanged: (v) => setState(() => _muteAll = v)),
            const SizedBox(height: 8),
            _SettingsTile(title: 'Lesebestätigungen senden', value: _readReceipts, onChanged: (v) => setState(() => _readReceipts = v)),
            const SizedBox(height: 8),
            _SettingsTile(title: 'Chats automatisch archivieren', value: _archiveAuto, onChanged: (v) => setState(() => _archiveAuto = v)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Abbrechen'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Fertig'))),
            ])
          ]),
        ),
      ),
    );
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: sheet);
  }
}

class _SettingsTile extends StatelessWidget {
  final String title; final bool value; final ValueChanged<bool> onChanged;
  const _SettingsTile({required this.title, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _ChatThreadCard extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final String avatarUrl;
  final bool hasUnread;
  final String? bookingStatus;
  final VoidCallback onTap;
  const _ChatThreadCard({required this.name, required this.lastMessage, required this.time, required this.avatarUrl, required this.hasUnread, required this.bookingStatus, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Stack(children: [
                CircleAvatar(radius: 28, backgroundImage: NetworkImage(avatarUrl)),
                if (hasUnread)
                  Positioned(right: 0, top: 0, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFFB277), shape: BoxShape.circle))),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white))),
                    const SizedBox(width: 8),
                    Text(time, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
                  ]),
                  const SizedBox(height: 4),
                  Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
                  if (bookingStatus != null)
                    Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.12))), child: Text(bookingStatus!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)))
                ]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ]),
          ),
        ),
      ),
    );
  }
}
