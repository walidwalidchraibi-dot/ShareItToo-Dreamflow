import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/screens/own_profile_screen.dart';
import 'package:lendify/screens/my_listings_screen.dart';
import 'package:lendify/screens/owner_requests_screen.dart';
import 'package:lendify/screens/placeholder_screen.dart';
import 'package:lendify/screens/public_profile_screen.dart';
import 'package:lendify/screens/verification_intro_screen.dart';
import 'package:lendify/screens/edit_profile_screen.dart';
import 'package:lendify/screens/account_settings_screen.dart';
import 'package:lendify/screens/bookings_screen.dart';
import 'package:lendify/screens/notifications_screen.dart';
import 'package:lendify/screens/help_center_screen.dart';
import 'package:lendify/screens/legal_screen.dart';
import 'package:lendify/widgets/profile_header_card.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/box_chat_icon.dart';

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

  FeedbackValidation _validateFeedback(String input) {
    final raw = input;
    final text = raw.trim();
    if (text.isEmpty) {
      return const FeedbackValidation(valid: false, reason: null);
    }

    // 1) Mindestlänge
    if (text.runes.length < 20) {
      return const FeedbackValidation(valid: false, reason: 'Bitte beschreibe dein Feedback etwas genauer.');
    }

    // Normalize to simplify word analysis.
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r"[\n\t]+"), ' ')
        .replaceAll(RegExp(r"[^\p{L}\p{N} ]", unicode: true), ' ')
        .replaceAll(RegExp(r"\s+"), ' ')
        .trim();

    // 2) Wörterprüfung: mindestens 3 echte Wörter.
    final words = normalized.isEmpty ? <String>[] : normalized.split(' ');
    final realWords = <String>[];
    for (final w in words) {
      if (_isRealWord(w)) realWords.add(w);
    }

    if (realWords.length < 3) {
      return const FeedbackValidation(valid: false, reason: 'Bitte formuliere dein Feedback mit mindestens 3 Wörtern.');
    }

    // 3) Zeichenvielfalt / Wiederholungsmuster.
    final nonSpace = text.replaceAll(RegExp(r"\s+"), '');
    if (nonSpace.isNotEmpty) {
      final freq = <String, int>{};
      for (final r in nonSpace.runes) {
        final ch = String.fromCharCode(r).toLowerCase();
        freq[ch] = (freq[ch] ?? 0) + 1;
      }
      final maxCount = freq.values.fold<int>(0, (m, v) => v > m ? v : m);
      final ratio = maxCount / nonSpace.runes.length;
      if (ratio > 0.60) {
        return const FeedbackValidation(valid: false, reason: 'Bitte formuliere dein Feedback etwas konkreter.');
      }
    }

    // 3b) Nur ein Wort wiederholt (z.B. "test test test").
    final uniqueRealWords = realWords.toSet();
    if (uniqueRealWords.length == 1 && realWords.length >= 3) {
      return const FeedbackValidation(valid: false, reason: 'Bitte formuliere dein Feedback abwechslungsreicher.');
    }

    // 4) Spam-/Unsinnsfilter (Heuristiken)
    if (_looksLikeRandomLetters(normalized)) {
      return const FeedbackValidation(valid: false, reason: 'Bitte formuliere dein Feedback etwas konkreter.');
    }

    if (_looksLikeGenericSpam(realWords)) {
      return const FeedbackValidation(valid: false, reason: 'Bitte beschreibe kurz, was genau du meinst.');
    }

    return const FeedbackValidation(valid: true, reason: null);
  }

  bool _isRealWord(String word) {
    final w = word.trim();
    if (w.length < 2) return false;
    if (!RegExp(r"^[\p{L}\p{N}]+$", unicode: true).hasMatch(w)) return false;

    // Reject obvious keyboard spam / repeated patterns (asdf, aaaaa, xyzxyz, testtesttest)
    if (RegExp(r"^(.)\1{3,}$").hasMatch(w)) return false; // aaaa...
    if (_isRepeatedChunk(w)) return false; // xyzxyz, testtest...

    // Require at least one letter. If it's only digits, treat it as not a "real word".
    final hasLetter = RegExp(r"\p{L}", unicode: true).hasMatch(w);
    if (!hasLetter) return false;

    // A lightweight natural-language heuristic: at least one vowel.
    // (Allows DE umlauts and common latin vowels.)
    final hasVowel = RegExp(r"[aeiouäöüy]", unicode: true).hasMatch(w);
    if (!hasVowel) return false;

    return true;
  }

  bool _isRepeatedChunk(String word) {
    final w = word;
    if (w.length < 4) return false;
    for (int len = 2; len <= (w.length ~/ 2); len++) {
      if (w.length % len != 0) continue;
      final chunk = w.substring(0, len);
      final repeated = chunk * (w.length ~/ len);
      if (repeated == w) return true;
    }
    return false;
  }

  bool _looksLikeRandomLetters(String normalized) {
    // If it's mostly letters, but has very low vowel ratio and many distinct letters,
    // it's likely random text (e.g., "xqtrplm..." or "asdfghj...").
    final lettersOnly = normalized.replaceAll(RegExp(r"[^\p{L}]", unicode: true), '');
    if (lettersOnly.length < 20) return false;
    final vowels = RegExp(r"[aeiouäöüy]", unicode: true).allMatches(lettersOnly).length;
    final vowelRatio = vowels / lettersOnly.length;
    if (vowelRatio >= 0.18) return false;

    final distinct = lettersOnly.split('').toSet().length;
    final distinctRatio = distinct / lettersOnly.length;
    return distinctRatio > 0.25;
  }

  bool _looksLikeGenericSpam(List<String> realWords) {
    // Reject feedback that is basically a loop of generic filler words.
    const generic = {
      'ok',
      'okay',
      'gut',
      'nice',
      'cool',
      'top',
      'super',
      'danke',
      'thanks',
      'merci',
      'great',
      'perfekt',
    };
    final unique = realWords.toSet();
    if (unique.isEmpty) return false;
    if (unique.every(generic.contains) && realWords.length >= 3) return true;
    return false;
  }

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
    final bool _hasAnyNotifications = _hasNewRequests; // extend when adding more sources
    // JSON-like spec that defines the Profile menu structure
    final Map<String, dynamic> menuSpec = {
      'primaryActions': [
        {
          'id': 'verify_now',
          'labelKey': 'profile.action.verifyNow',
          'icon': 'badge-check',
          'route': '/verify',
          'visibleWhen': !verified,
        },
        {
          'id': 'view_public_profile',
          'labelKey': 'profile.action.viewMyProfile',
          'icon': 'user',
          'route': '/myProfilePublic',
          'visibleWhen': true,
        },
      ],
      'mainMenu': [
        {
          'id': 'my_listings',
          'labelKey': 'profile.menu.myListings',
          'icon': 'storefront',
          'route': '/myListings',
        },
        {
          'id': 'rental_requests',
          'labelKey': 'profile.menu.rentalRequests',
          'icon': 'requests',
          'route': '/ownerRequests',
          'showDot': _hasNewRequests,
        },
        {
          'id': 'my_bookings',
          'labelKey': 'profile.menu.myBookings',
          'icon': 'calendar',
          'route': '/bookings',
          // Only show when real notifications exist (not implemented yet)
          // 'showDot': _hasNewBookings,
        },
      ],
      'secondaryMenu': [
        {
          'id': 'account_settings',
          'labelKey': 'profile.menu.accountSettings',
          'icon': 'settings',
          'route': '/accountSettings',
          // 'showDot': _hasNewAccountNotices,
        },
        {
          'id': 'help_center',
          'labelKey': 'profile.menu.helpCenter',
          'icon': 'help',
          'route': '/help',
          // 'showDot': _hasNewHelpUpdates,
        },
        {
          'id': 'legal',
          'labelKey': 'profile.menu.legal',
          'icon': 'legal',
          'route': '/legal',
          // 'showDot': _hasNewLegalUpdates,
        },
        {
          'id': 'language',
          'labelKey': 'profile.menu.language',
          'icon': 'language',
          'route': '/language',
        },
        {
          'id': 'logout',
          'labelKey': 'profile.menu.logout',
          'icon': 'logout',
          'route': '/logout',
          'destructive': true,
        },
      ],
    };
    final profileKey = ValueKey('profile-${userForDisplay.id}-${_myListingsCount}-${userForDisplay.avgRating.toStringAsFixed(2)}-${userForDisplay.reviewCount}');
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
        title: Text(l10n.t('Profil')),
        actions: [
          Transform.translate(
            offset: const Offset(-12.6, 0), // shift ~3mm to the left
            child: Stack(children: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
                icon: const Icon(Icons.notifications_outlined),
              ),
              if (_hasAnyNotifications)
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
          // Primary actions (from JSON spec)
          Column(children: [
            for (final action in (menuSpec['primaryActions'] as List))
              if (action['visibleWhen'] == true) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _handleRoute(action['route'] as String),
                    icon: _iconFromSpec(action['icon'] as String),
                    label: Text(l10n.t(action['labelKey'] as String)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
          ]),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
            child: Column(children: [
              for (int i = 0; i < (menuSpec['mainMenu'] as List).length; i++) ...[
                _buildMenuFromSpec(menuSpec['mainMenu'][i] as Map<String, dynamic>, l10n),
                if (i < (menuSpec['mainMenu'] as List).length - 1) _divider(),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
            child: Column(children: [
              for (int i = 0; i < (menuSpec['secondaryMenu'] as List).length; i++) ...[
                _buildMenuFromSpec(menuSpec['secondaryMenu'][i] as Map<String, dynamic>, l10n),
                if (i < (menuSpec['secondaryMenu'] as List).length - 1) _divider(),
              ],
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

  // removed legacy _svgIcon helper after switching to composed icon

  Widget _buildMenuItem(IconData icon, String title, {bool isDestructive = false, bool showDot = false, Widget? leadingOverride, VoidCallback? onTapOverride}) {
    final l10n = context.read<LocalizationController>();
    // Place the dot left (on the leading icon) for all items that request a dot
    final placeDotLeft = showDot;
    final baseLeading = leadingOverride ?? Icon(icon, color: isDestructive ? Colors.red : Colors.white70);
    final leadingWithDotLeft = SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
        // Center the original leading widget
        Center(child: SizedBox(width: 22, height: 22, child: FittedBox(child: baseLeading))),
        // Orange badge; after feedback: move ~1mm back towards center on both axes
        // ~1mm ≈ 4.2 logical px on typical densities
        Positioned(left: -4.2, top: -2.2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFB277), shape: BoxShape.circle))),
      ]),
    );

    return ListTile(
      leading: placeDotLeft ? leadingWithDotLeft : baseLeading,
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDestructive ? Colors.red : Colors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot && !placeDotLeft) ...[
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFB277), shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right, color: Colors.white38),
        ],
      ),
      onTap: () {
        if (onTapOverride != null) { onTapOverride(); return; }
        switch (title) {
          case 'Meine Anzeigen':
          case 'My listings':
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyListingsScreen()));
            break;
          case 'Meine Buchungen':
          case 'My bookings':
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingsScreen()));
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
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
            break;
          case 'Hilfe-Center':
          case 'Help Center':
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceholderScreen(title: l10n.t('Hilfe-Center'), description: 'FAQ und Support.')));
            break;
          case 'Rechtliches':
          case 'Legal':
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen()));
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

  // Build a menu entry from the JSON-like spec
  Widget _buildMenuFromSpec(Map<String, dynamic> spec, LocalizationController l10n) {
    final title = l10n.t(spec['labelKey'] as String);
    final iconName = (spec['icon'] as String?) ?? '';
    final showDot = (spec['showDot'] as bool?) ?? false;
    final isDestructive = (spec['destructive'] as bool?) ?? false;
    final iconData = _iconDataFromSpec(iconName);
    final leadingOverride = iconName == 'requests' ? const BoxChatIcon(size: 22, color: Colors.white70) : null;
    final String? route = spec['route'] as String?;
    return _buildMenuItem(
      iconData,
      title,
      isDestructive: isDestructive,
      showDot: showDot,
      leadingOverride: leadingOverride,
      onTapOverride: route != null ? () => _handleRoute(route) : null,
    );
  }

  // Map abstract icon names from the spec to Material icons
  Icon _iconFromSpec(String name) => Icon(_iconDataFromSpec(name));

  IconData _iconDataFromSpec(String name) {
    switch (name) {
      case 'badge-check':
        return Icons.verified_user_outlined;
      case 'user':
        return Icons.person_outline;
      case 'storefront':
        return Icons.storefront_outlined;
      case 'requests':
        return Icons.mark_unread_chat_alt_outlined;
      case 'calendar':
        return Icons.calendar_month_outlined;
      case 'settings':
        return Icons.settings_outlined;
      case 'help':
        return Icons.help_outline;
      case 'legal':
        return Icons.article_outlined;
      case 'language':
        return Icons.language;
      case 'logout':
        return Icons.logout;
      default:
        return Icons.chevron_right;
    }
  }

  void _handleRoute(String route) {
    switch (route) {
      case '/verify':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerificationIntroScreen()));
        break;
      case '/myProfilePublic':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PublicProfileScreen()));
        break;
      case '/myListings':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyListingsScreen()));
        break;
      case '/ownerRequests':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OwnerRequestsScreen(initialTabIndex: 2))).then((_) { if (mounted) { _load(); } });
        break;
      case '/bookings':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingsScreen()));
        break;
      case '/accountSettings':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
        break;
      case '/help':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpCenterScreen()));
        break;
      case '/legal':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen()));
        break;
      case '/language':
        _openLanguageSheet();
        break;
      case '/logout':
        _confirmLogout();
        break;
      default:
        break;
    }
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
    final validation = _validateFeedback(_feedbackCtrl.text);
    final canSend = !_sendingFeedback && validation.valid;
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
              hintText: 'Was gefällt dir an ShareItToo – oder was können wir verbessern?',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.6))),
            ),
          ),
          if (!validation.valid && (_feedbackCtrl.text.trim().isNotEmpty) && (validation.reason != null)) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                validation.reason!,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60, height: 1.35),
              ),
            ),
          ],
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
    final validation = _validateFeedback(text);
    if (!validation.valid) return;
    setState(() { _sendingFeedback = true; });
    try {
      await DataService.addFeedback(userId: _user!.id, text: text);
      if (!mounted) return;
      setState(() {
        _feedbackCtrl.clear();
        _sendingFeedback = false;
      });
      _feedbackFocus.unfocus();

      await AppPopup.show(
        context,
        icon: Icons.check_circle_outline,
        title: 'Danke für dein Feedback',
        message: 'Wir lesen jedes Feedback persönlich und nutzen es, um ShareItToo zu verbessern.',
        showCloseIcon: false,
        leadingWidget: _sitCelebrationBadge(),
        accentGradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary,
          ],
        ),
        borderColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        useExploreBackground: true,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
              child: const Text('Schließen'),
            ),
          ),
        ],
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

@immutable
class FeedbackValidation {
  final bool valid;
  final String? reason;
  const FeedbackValidation({required this.valid, required this.reason});
}