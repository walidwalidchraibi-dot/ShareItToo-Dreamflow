import 'package:flutter/material.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:provider/provider.dart';
import 'package:lendify/widgets/app_popup.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  User? _user;
  final _workCtrl = TextEditingController();
  final _hobbiesCtrl = TextEditingController();
  final _homeLocCtrl = TextEditingController();
  final _favSongCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _showWork = false;
  bool _showHobbies = false;
  bool _showHomeLocation = false;
  bool _showBioPublic = true;
  bool _showFavoriteSong = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await DataService.getCurrentUser();
    setState(() {
      _user = u;
      _workCtrl.text = u?.workTitle ?? '';
      _hobbiesCtrl.text = u?.hobbies ?? '';
      _homeLocCtrl.text = u?.homeLocation ?? (u?.city != null ? '${u!.city}, ${u.country ?? ''}' : '');
      _favSongCtrl.text = u?.favoriteSong ?? '';
      _bioCtrl.text = u?.bio ?? '';
      _showWork = u?.showWork ?? false;
      _showHobbies = u?.showHobbies ?? false;
      _showHomeLocation = u?.showHomeLocation ?? false;
      _showBioPublic = u?.showBioPublic ?? true;
      _showFavoriteSong = u?.showFavoriteSong ?? false;
    });
  }

  @override
  void dispose() {
    _workCtrl.dispose();
    _hobbiesCtrl.dispose();
    _homeLocCtrl.dispose();
    _favSongCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_user == null) return;
    final updated = User(
      id: _user!.id,
      displayName: _user!.displayName,
      email: _user!.email,
      phone: _user!.phone,
      photoURL: _user!.photoURL,
      bio: _bioCtrl.text,
      city: _user!.city,
      country: _user!.country,
      preferredLanguage: _user!.preferredLanguage,
      isVerified: _user!.isVerified,
      isBanned: _user!.isBanned,
      role: _user!.role,
      payoutAccountId: _user!.payoutAccountId,
      avgRating: _user!.avgRating,
      reviewCount: _user!.reviewCount,
      createdAt: _user!.createdAt,
      languages: _user!.languages,
      interests: _user!.interests,
      workTitle: _workCtrl.text.isEmpty ? null : _workCtrl.text,
      hobbies: _hobbiesCtrl.text.isEmpty ? null : _hobbiesCtrl.text,
      homeLocation: _homeLocCtrl.text.isEmpty ? null : _homeLocCtrl.text,
      favoriteSong: _favSongCtrl.text.isEmpty ? null : _favSongCtrl.text,
      showWork: _showWork,
      showHobbies: _showHobbies,
      showHomeLocation: _showHomeLocation,
      showBioPublic: _showBioPublic,
      showFavoriteSong: _showFavoriteSong,
    );
    await DataService.setCurrentUser(updated);
    if (!mounted) return;
    AppPopup.toast(context, icon: Icons.check_circle_outline, title: context.read<LocalizationController>().t('Gespeichert'));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('Profil bearbeiten'))),
      body: _user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Section(title: l10n.t('Öffentliche Angaben')),
                _TextFieldTile(label: l10n.t('Beruf / Rolle'), controller: _workCtrl, icon: Icons.work_outline),
                _SwitchTile(title: l10n.t('Im öffentlichen Profil anzeigen'), value: _showWork, onChanged: (v) => setState(() => _showWork = v)),
                const SizedBox(height: 12),
                _TextFieldTile(label: l10n.t('Hobbys (kommagetrennt)'), controller: _hobbiesCtrl, icon: Icons.interests),
                _SwitchTile(title: l10n.t('Im öffentlichen Profil anzeigen'), value: _showHobbies, onChanged: (v) => setState(() => _showHobbies = v)),
                const SizedBox(height: 12),
                _TextFieldTile(label: l10n.t('Wohnort (optional, überschreibt Stadt)'), controller: _homeLocCtrl, icon: Icons.home_outlined),
                _SwitchTile(title: l10n.t('Im öffentlichen Profil anzeigen'), value: _showHomeLocation, onChanged: (v) => setState(() => _showHomeLocation = v)),
                const SizedBox(height: 12),
                _TextFieldTile(label: l10n.t('Lieblingssong'), controller: _favSongCtrl, icon: Icons.music_note_outlined),
                _SwitchTile(title: l10n.t('Im öffentlichen Profil anzeigen'), value: _showFavoriteSong, onChanged: (v) => setState(() => _showFavoriteSong = v)),
                const Divider(height: 32),
                _Section(title: l10n.t('Über mich')),
                _TextAreaTile(label: l10n.t('Über mich'), controller: _bioCtrl, icon: Icons.person_outline),
                _SwitchTile(title: l10n.t('Über mich öffentlich anzeigen'), value: _showBioPublic, onChanged: (v) => setState(() => _showBioPublic = v)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: Text(l10n.t('Speichern')))),
              ]),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: Theme.of(context).textTheme.titleMedium));
}

class _TextFieldTile extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  const _TextFieldTile({required this.label, required this.controller, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: TextField(controller: controller, decoration: InputDecoration(hintText: label, border: InputBorder.none), style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _TextAreaTile extends StatelessWidget {
  final String label; final TextEditingController controller; final IconData icon;
  const _TextAreaTile({required this.label, required this.controller, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: Colors.white70), const SizedBox(width: 8), Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70))]),
          TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(border: InputBorder.none), style: const TextStyle(color: Colors.white))
        ]),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title; final bool value; final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.title, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeColor: Theme.of(context).colorScheme.primary,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
