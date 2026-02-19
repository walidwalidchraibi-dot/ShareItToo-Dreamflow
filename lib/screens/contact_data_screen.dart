import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';
import 'package:lendify/screens/edit_social_media_screen.dart';
import 'package:lendify/screens/change_email_screen.dart';
import 'package:lendify/screens/change_phone_screen.dart';
import 'package:lendify/screens/change_address_screen.dart';

class ContactDataScreen extends StatefulWidget {
  const ContactDataScreen({super.key});
  @override
  State<ContactDataScreen> createState() => _ContactDataScreenState();
}

class _ContactDataScreenState extends State<ContactDataScreen> {
  User? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await DataService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = u;
      _loading = false;
    });
  }

  String _addressDisplay(User u) {
    final line = (u.homeLocation ?? '').trim();
    if (line.isNotEmpty) return line;
    final city = (u.city ?? '').trim();
    final country = (u.country ?? '').trim();
    if (city.isEmpty && country.isEmpty) return '—';
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }

  String _socialSummary(User u) {
    final parts = <String>[];
    if ((u.socialX ?? '').trim().isNotEmpty) parts.add('X');
    if ((u.socialInstagram ?? '').trim().isNotEmpty) parts.add('Instagram');
    if ((u.socialFacebook ?? '').trim().isNotEmpty) parts.add('Facebook');
    if ((u.socialTiktok ?? '').trim().isNotEmpty) parts.add('TikTok');
    if ((u.socialSnapchat ?? '').trim().isNotEmpty) parts.add('Snapchat');
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    final user = _user;
    return Stack(children: [
      Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: Container(color: Colors.black.withValues(alpha: 0.35)))),
      Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(l10n.t('account.item.contactData')),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _InfoRow(
                    icon: Icons.alternate_email,
                    label: 'E‑Mail',
                    value: user?.email ?? '—',
                    actionLabel: 'Ändern',
                    onAction: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangeEmailScreen()));
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Telefon',
                    value: user?.phone ?? '—',
                    actionLabel: 'Ändern',
                    onAction: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePhoneScreen()));
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.place_outlined,
                    label: 'Adresse',
                    value: user != null ? _addressDisplay(user) : '—',
                    actionLabel: 'Ändern',
                    onAction: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangeAddressScreen()));
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.share_outlined,
                    label: 'Social Media',
                    value: user != null ? _socialSummary(user) : '—',
                    actionLabel: 'Bearbeiten',
                    onAction: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditSocialMediaScreen()));
                      _load();
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('E‑Mail, Telefon und Adresse sind niemals öffentlich sichtbar.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('Deine Social‑Links können auf dem öffentlichen Profil erscheinen.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60)),
                ]),
              ),
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String actionLabel;
  final VoidCallback onAction;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.actionLabel, required this.onAction});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
        ])),
        const SizedBox(width: 12),
        OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
      ]),
    );
  }
}
