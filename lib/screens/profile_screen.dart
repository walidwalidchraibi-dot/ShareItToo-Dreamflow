import 'package:flutter/material.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/screens/own_profile_screen.dart';
import 'package:lendify/screens/my_listings_screen.dart';
import 'package:lendify/screens/owner_requests_screen.dart';
import 'package:lendify/screens/placeholder_screen.dart';
import 'package:lendify/screens/public_profile_screen.dart';
import 'package:lendify/screens/verification_intro_screen.dart';
import 'package:lendify/screens/edit_profile_screen.dart';
import 'package:lendify/widgets/profile_header_card.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  int _myListingsCount = 0;
  bool _isLoading = true;
  bool _hasNewRequests = false;
  // Feedback state
  final TextEditingController _feedbackCtrl = TextEditingController();
  final FocusNode _feedbackFocus = FocusNode();
  bool _sendingFeedback = false;

  @override
  void initState() {
    super.initState();
    _user = _placeholderUser();
    _load();
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    _feedbackFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    User? maybeUser = await DataService.getCurrentUser();
    if (maybeUser == null) {
      final users = await DataService.getUsers();
      if (users.isNotEmpty) {
        maybeUser = users.first;
      }
    }
    final user = maybeUser ?? _placeholderUser();
    final items = await DataService.getItems();
    final count = items.where((e) => e.ownerId == user.id).length;
    final hasNew = await DataService.hasNewOwnerRequests(user.id);
    if (!mounted) return;
    setState(() {
      _user = user;
      _myListingsCount = count;
      _isLoading = false;
      _hasNewRequests = hasNew;
    });
  }

  User _placeholderUser() {
    final now = DateTime.now();
    return User(
      id: 'placeholder-user',
      displayName: 'Walid Chraibi',
      email: 'walid.placeholder@shareittoo.demo',
      city: 'Berlin',
      country: 'Deutschland',
      preferredLanguage: 'de-DE',
      isVerified: false,
      isBanned: false,
      role: 'user',
      avgRating: 4.7,
      reviewCount: 32,
      createdAt: now.subtract(const Duration(days: 480)),
      photoURL: 'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=150&h=150&fit=crop&crop=face',
      languages: const ['Deutsch'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final userForDisplay = _user ?? _placeholderUser();
    final verified = userForDisplay.isVerified;
    final profileKey = ValueKey('profile-${userForDisplay.id}-${_myListingsCount}-${userForDisplay.avgRating.toStringAsFixed(2)}-${userForDisplay.reviewCount}');
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: Text(l10n.t('Profil')),
        actions: [
          Transform.translate(
            offset: const Offset(-12.6, 0), // shift ~3mm to the left
            child: Stack(children: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaceholderScreen(title: l10n.t('Benachrichtigungen'), description: l10n.t('Hier siehst du künftig deine Benachrichtigungen.')),
                  ),
                ),
                icon: const Icon(Icons.notifications_outlined),
              ),
              Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFB277), shape: BoxShape.circle))),
            ]),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 40),
        child: Column(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            child: AnimatedOpacity(
              key: profileKey,
              duration: const Duration(milliseconds: 200),
              opacity: _isLoading ? 0.55 : 1.0,
              child: ProfileHeaderCard(
                user: userForDisplay,
                listingsCount: _myListingsCount,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Visibility(
            visible: !verified,
            maintainAnimation: true,
            maintainState: true,
            maintainSize: true,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerificationIntroScreen())),
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Jetzt verifizieren'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PublicProfileScreen())),
              child: Text(l10n.t('Mein Profil anzeigen')),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
            child: Column(children: [
              _buildMenuItem(Icons.storefront_outlined, l10n.t('Meine Anzeigen')),
              _divider(),
              // Renamed: Requests -> Mietanfragen
              _buildMenuItem(Icons.mark_unread_chat_alt_outlined, 'Mietanfragen', showDot: _hasNewRequests),
              _divider(),
              // Removed: Vergangene Buchungen
              _buildMenuItem(Icons.people_outline, l10n.t('Kontakte')),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
            child: Column(children: [
              _buildMenuItem(Icons.settings_outlined, l10n.t('Kontoeinstellungen')),
              _divider(),
              _buildMenuItem(Icons.help_outline, l10n.t('Hilfe-Center')),
              _divider(),
              _buildMenuItem(Icons.article_outlined, l10n.t('Rechtliches')),
              _divider(),
              _buildMenuItem(Icons.language, l10n.t('Sprache')),
              _divider(),
              _buildMenuItem(Icons.logout, l10n.t('Abmelden'), isDestructive: true),
            ]),
          ),
          const SizedBox(height: 16),
          _buildFeedbackSection(),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, thickness: 1, color: Colors.white24);

  Widget _buildStatItem(String value, String label) {
    return Column(children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
    ]);
  }

  Widget _buildMenuItem(IconData icon, String title, {bool isDestructive = false, bool showDot = false}) {
    final l10n = context.read<LocalizationController>();
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.white70),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDestructive ? Colors.red : Colors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFB277), shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right, color: Colors.white38),
        ],
      ),
      onTap: () {
        switch (title) {
          case 'Meine Anzeigen':
          case 'My listings':
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyListingsScreen()));
            break;
          case 'Anfragen':
          case 'Requests':
          case 'Mietanfragen':
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const OwnerRequestsScreen(initialTabIndex: 2)))
                .then((_) { if (mounted) { _load(); } });
            break;
          case 'Kontakte':
          case 'Contacts':
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceholderScreen(title: l10n.t('Kontakte'), description: l10n.t('Verwalte deine Kontakte und Vermieter.'))));
            break;
          case 'Kontoeinstellungen':
          case 'Account settings':
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
            break;
          case 'Hilfe-Center':
          case 'Help Center':
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceholderScreen(title: l10n.t('Hilfe-Center'), description: 'FAQ und Support.')));
            break;
          case 'Rechtliches':
          case 'Legal':
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceholderScreen(title: l10n.t('Rechtliches'), description: 'AGB, Datenschutz und Impressum.')));
            break;
          case 'Sprache':
          case 'Language':
            _openLanguageSheet();
            break;
          case 'Abmelden':
          case 'Log out':
            _confirmLogout();
            break;
            default:
              AppPopup.toast(context, icon: Icons.hourglass_bottom, title: l10n.t('Bald verfügbar'));
        }
      },
    );
  }

  void _openLanguageSheet() {
    final l10n = context.read<LocalizationController>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.7),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final current = context.watch<LocalizationController>().language;
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RadioListTile<AppLanguage>(
              value: AppLanguage.de,
              groupValue: current,
              activeColor: Theme.of(context).colorScheme.primary,
              title: Text(l10n.t('Deutsch'), style: const TextStyle(color: Colors.white)),
              onChanged: (_) async {
                await context.read<LocalizationController>().setLanguage(AppLanguage.de);
                if (!mounted) return;
                Navigator.of(context).maybePop();
              },
            ),
            RadioListTile<AppLanguage>(
              value: AppLanguage.en,
              groupValue: current,
              activeColor: Theme.of(context).colorScheme.primary,
              title: Text(l10n.t('English'), style: const TextStyle(color: Colors.white)),
              onChanged: (_) async {
                await context.read<LocalizationController>().setLanguage(AppLanguage.en);
                if (!mounted) return;
                Navigator.of(context).maybePop();
              },
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  void _confirmLogout() {
    final l10n = context.read<LocalizationController>();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.t('Abmelden?')),
          content: Text(l10n.t('Du kannst dich jederzeit wieder anmelden.')),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.t('Abbrechen'))),
            FilledButton(onPressed: () {
              Navigator.of(context)..pop()..maybePop();
              final l10n = context.read<LocalizationController>();
              AppPopup.toast(context, icon: Icons.logout, title: l10n.t('Abgemeldet (Demo)'));
            }, child: Text(l10n.t('Abmelden'))),
          ],
        );
      },
    );
  }

  Widget _buildFeedbackSection() {
    final theme = Theme.of(context);
    final canSend = !_sendingFeedback && _hasAtLeastOneWord(_feedbackCtrl.text);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined, color: Colors.white70),
              const SizedBox(width: 8),
              Text('Feedback zur App', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sag uns, was dir gefällt – oder was wir besser machen können. Dein Feedback hilft uns, ShareItToo zu verbessern. Wir lesen jede Nachricht persönlich.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedbackCtrl,
            focusNode: _feedbackFocus,
            maxLines: 5,
            minLines: 3,
            onChanged: (_) => setState(() {}),
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: '✏️ Dein Feedback …',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.6))),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: canSend ? _submitFeedback : null,
                  child: _sendingFeedback
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Absenden'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasAtLeastOneWord(String input) {
    final text = input.trim();
    if (text.isEmpty) return false;
    // Require at least one alphanumeric character (covers umlauts via Latin-1 range)
    return RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ0-9]').hasMatch(text);
  }

  Widget _sitCelebrationBadge() {
    // Show only the SIT logo (no round badge), exactly 46px and centered.
    // Nudge the logo visually ~1mm downward (~4 logical pixels)
    return SizedBox(
      width: 46,
      height: 46,
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, 4),
          child: Image.asset(
            'assets/images/icononly_transparent_nobuffer.png',
            width: 46,
            height: 46,
          ),
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (_user == null) return;
    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _sendingFeedback = true; });
    try {
      await DataService.addFeedback(userId: _user!.id, text: text);
      if (!mounted) return;
      setState(() {
        _feedbackCtrl.clear();
        _sendingFeedback = false;
      });
      _feedbackFocus.unfocus();
      AppPopup.toast(
        context,
        icon: Icons.check_circle_outline,
        title: 'Danke, dass du die ShareItToo App mitgestaltest.',
        message: 'Dein Feedback hilft uns, die Plattform für alle besser zu machen.',
        duration: const Duration(seconds: 7),
        leadingWidget: _sitCelebrationBadge(),
        // Use app blue color for the Danke popup accent
        accentGradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary,
          ],
        ),
        borderColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
          // Use blurred Explore background inside the card
          useExploreBackground: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _sendingFeedback = false; });
      AppPopup.toast(
        context,
        icon: Icons.error_outline,
        title: 'Senden fehlgeschlagen',
        message: 'Bitte versuche es erneut.',
      );
    }
  }
}