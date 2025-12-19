import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:lendify/widgets/app_popup.dart';

class MessageThreadScreen extends StatefulWidget {
  final String participantName;
  final String? avatarUrl;
  const MessageThreadScreen({super.key, required this.participantName, this.avatarUrl});

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _listController = ScrollController();
  double _lastViewInsetBottom = 0;
  bool _isAtBottom = true;
  bool _showJumpToBottom = false;
  final List<_ChatBubbleModel> _messages = [
    _ChatBubbleModel(text: 'Hallo! Ist der Artikel noch verfügbar?', me: false, time: '10:12'),
    _ChatBubbleModel(text: 'Ja, auf jeden Fall. Wann passt dir die Abholung?', me: true, time: '10:14'),
  ];

  void _openMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      backgroundColor: Colors.transparent,
      builder: (context) => const _ThreadMoreSheet(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatBubbleModel(text: text, me: true, time: _now()));
    });
    _controller.clear();
    // Keep view pinned to bottom on send
    _scrollToBottom(animate: true);
  }

  String _now() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Observe keyboard inset changes to maintain bottom pinning
    final insets = MediaQuery.of(context).viewInsets.bottom;
    if (insets != _lastViewInsetBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final opened = insets > 0 && _lastViewInsetBottom == 0;
        _lastViewInsetBottom = insets;
        if (opened && _isAtBottom) {
          _scrollToBottom(animate: true);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: Row(children: [
          CircleAvatar(radius: 14, backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null, child: widget.avatarUrl == null ? const Icon(Icons.person, size: 16) : null),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.participantName, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(onPressed: () => AppPopup.toast(context, icon: Icons.call, title: 'Anrufen (Demo)'), icon: const Icon(Icons.call)),
          IconButton(onPressed: _openMoreSheet, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: Stack(children: [
        Column(children: [
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                if (n.direction == ScrollDirection.forward && _inputFocus.hasFocus) {
                  // Scroll down gesture while typing hides keyboard (optional behavior)
                  FocusScope.of(context).unfocus();
                }
                return false;
              },
              child: ListView.builder(
                controller: _listController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  return Align(
                    alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
                    child: _ChatBubble(text: m.text, me: m.me, time: m.time),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    focusNode: _inputFocus,
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    onTap: () {
                      // Scroll latest into view when focusing input
                      Future.delayed(const Duration(milliseconds: 50), () => _scrollToBottom(animate: true));
                    },
                    decoration: InputDecoration(
                      hintText: 'Nachricht schreiben …',
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ]),
            ),
          ),
        ]),

        // "Nach unten" FAB when not at bottom
        if (_showJumpToBottom)
          Positioned(
            right: 16,
            bottom: (MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom : 0) + 80,
            child: FloatingActionButton.small(
              onPressed: () => _scrollToBottom(animate: true),
              child: const Icon(Icons.arrow_downward),
            ),
          ),
      ]),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initial scroll to bottom after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _listController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_listController.hasClients) return;
    final pos = _listController.position;
    final atBottomNow = pos.pixels >= (pos.maxScrollExtent - 8);
    if (atBottomNow != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottomNow;
        _showJumpToBottom = !atBottomNow;
      });
    }
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_listController.hasClients) return;
    final max = _listController.position.maxScrollExtent;
    if (animate) {
      _listController.animateTo(max, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _listController.jumpTo(max);
    }
  }
}

class _ChatBubbleModel {
  final String text; final bool me; final String time;
  _ChatBubbleModel({required this.text, required this.me, required this.time});
}

class _ThreadMoreSheet extends StatelessWidget {
  const _ThreadMoreSheet();
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(children: [
            Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: Container(color: Colors.transparent))),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 720),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    height: 44,
                    child: Stack(children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)))),
                      const Positioned.fill(child: Center(child: Text('Mehr', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)))),
                      Positioned(right: 16, top: 0, bottom: 0, child: SizedBox(width: 44, height: 44, child: InkWell(borderRadius: BorderRadius.circular(22), onTap: () => Navigator.of(context).maybePop(), child: const Center(child: Icon(Icons.close, color: Colors.white)))))
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _MoreAction(icon: Icons.person, label: 'Profil ansehen', onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 8),
                  _MoreAction(icon: Icons.notifications_off_outlined, label: 'Stummschalten', onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 8),
                  _MoreAction(icon: Icons.block_outlined, label: 'Blockieren', onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 8),
                  _MoreAction(icon: Icons.flag_outlined, label: 'Melden', onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 8),
                ])),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MoreAction extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _MoreAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
        child: Row(children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
        ]),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text; final bool me; final String time;
  const _ChatBubble({required this.text, required this.me, required this.time});
  @override
  Widget build(BuildContext context) {
    final bg = me ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.06);
    final fg = me ? Colors.white : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: TextStyle(color: fg)),
        const SizedBox(height: 4),
        Align(alignment: Alignment.bottomRight, child: Text(time, style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 10))),
      ]),
    );
  }
}
