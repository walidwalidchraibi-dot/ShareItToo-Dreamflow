import 'package:flutter/material.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/localization_service.dart';

class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});
  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  User? _user;
  bool _loading = true;

  // Controllers
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _workCtrl = TextEditingController();
  final _hobbiesCtrl = TextEditingController();
  final _homeLocCtrl = TextEditingController();
  final _favSongCtrl = TextEditingController();
  final _languagesCtrl = TextEditingController();
  final _interestsCtrl = TextEditingController();

  // Toggles
  bool _showWork = false;
  bool _showHobbies = false;
  bool _showHomeLocation = false;
  bool _showBioPublic = true;
  bool _showFavoriteSong = false;

  // Other
  String _preferredLang = 'de-DE';
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = await DataService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = u;
        _loading = false;
        if (u != null) {
          _displayNameCtrl.text = u.displayName;
          _bioCtrl.text = u.bio ?? '';
          _workCtrl.text = u.workTitle ?? '';
          _hobbiesCtrl.text = u.hobbies ?? '';
          _homeLocCtrl.text = u.homeLocation ?? '';
          _favSongCtrl.text = u.favoriteSong ?? '';
          _languagesCtrl.text = u.languages.join(', ');
          _interestsCtrl.text = u.interests.join(', ');
          _showWork = u.showWork;
          _showHobbies = u.showHobbies;
          _showHomeLocation = u.showHomeLocation;
          _showBioPublic = u.showBioPublic;
          _showFavoriteSong = u.showFavoriteSong;
          _preferredLang = u.preferredLanguage;
          _birthDate = u.birthDate;
        }
      });
    } catch (e) {
      // just fallback to empty; DataService already logs critical errors when needed
      setState(() { _loading = false; });
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _workCtrl.dispose();
    _hobbiesCtrl.dispose();
    _homeLocCtrl.dispose();
    _favSongCtrl.dispose();
    _languagesCtrl.dispose();
    _interestsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1900, 1, 1), lastDate: DateTime(now.year - 14, 12, 31));
    if (picked != null) setState(() => _birthDate = picked);
  }

  List<String> _splitToList(String raw) => raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    final u = _user;
    if (u == null) return;
    final updated = u.copyWith(
      displayName: _displayNameCtrl.text.trim().isEmpty ? u.displayName : _displayNameCtrl.text.trim(),
      bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      workTitle: _workCtrl.text.trim().isEmpty ? null : _workCtrl.text.trim(),
      hobbies: _hobbiesCtrl.text.trim().isEmpty ? null : _hobbiesCtrl.text.trim(),
      homeLocation: _homeLocCtrl.text.trim().isEmpty ? null : _homeLocCtrl.text.trim(),
      favoriteSong: _favSongCtrl.text.trim().isEmpty ? null : _favSongCtrl.text.trim(),
      showWork: _showWork,
      showHobbies: _showHobbies,
      showHomeLocation: _showHomeLocation,
      showBioPublic: _showBioPublic,
      showFavoriteSong: _showFavoriteSong,
      preferredLanguage: _preferredLang,
      languages: _splitToList(_languagesCtrl.text),
      interests: _splitToList(_interestsCtrl.text),
      birthDate: _birthDate,
    );
    await DataService.setCurrentUser(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('Profilinformationen'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Section(title: l10n.t('Allgemein')),
                _TextFieldTile(label: l10n.t('Anzeigename'), controller: _displayNameCtrl, icon: Icons.badge_outlined),
                const SizedBox(height: 12),
                _TextAreaTile(label: l10n.t('Über mich'), controller: _bioCtrl, icon: Icons.person_outline),
                _SwitchTile(title: l10n.t('Über mich öffentlich anzeigen'), value: _showBioPublic, onChanged: (v) => setState(() => _showBioPublic = v)),
                const Divider(height: 32),
                _Section(title: l10n.t('Öffentliche Angaben')),
                _TextFieldTile(label: l10n.t('Beruf / Rolle'), controller: _workCtrl, icon: Icons.work_outline),
                _SwitchTile(title: l10n.t('Im öffentlichen Profil anzeigen'), value: _showWork, onChanged: (v) => setState(() => _showWork = v)),
                const SizedBox(height: 12),
                _TextFieldTile(label: l10n.t('Hobbys (kommagetrennt)'), controller: _hobbiesCtrl, icon: Icons.interests),
                _SwitchTile(title: l10n.t('Im öffentlichen Profil anzeigen'), value: _showHobbies, onChanged: (v) => setState(() => _showHobbies = v)),
                const SizedBox(height: 12),
                _TextFieldTile(label: l10n.t('Wohnort (öffentlich, optional)'), controller: _homeLocCtrl, icon: Icons.home_outlined),
                _SwitchTile(title: l10n.t('Im öffentlichen Profil anzeigen'), value: _showHomeLocation, onChanged: (v) => setState(() => _showHomeLocation = v)),
                const SizedBox(height: 12),
                _TextFieldTile(label: l10n.t('Lieblingssong'), controller: _favSongCtrl, icon: Icons.music_note_outlined),
                _SwitchTile(title: l10n.t('Im öffentlichen Profil anzeigen'), value: _showFavoriteSong, onChanged: (v) => setState(() => _showFavoriteSong = v)),
                const Divider(height: 32),
                _Section(title: l10n.t('Sprachen & Interessen')),
                _DropdownTile(
                  label: l10n.t('Bevorzugte Sprache'),
                  value: _preferredLang,
                  icon: Icons.language,
                  items: const ['de-DE', 'en-US', 'fr-FR', 'es-ES'],
                  onChanged: (v) => setState(() => _preferredLang = v ?? _preferredLang),
                ),
                const SizedBox(height: 12),
                _TextFieldTile(label: l10n.t('Weitere Sprachen (kommagetrennt)'), controller: _languagesCtrl, icon: Icons.translate),
                const SizedBox(height: 12),
                _TextFieldTile(label: l10n.t('Interessen (kommagetrennt)'), controller: _interestsCtrl, icon: Icons.tag_outlined),
                const Divider(height: 32),
                _Section(title: l10n.t('Privat')),
                _DateTile(label: l10n.t('Geburtsdatum (privat)'), date: _birthDate, onTap: _pickBirthDate),
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
  final String label;
  final TextEditingController controller;
  final IconData icon;
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
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.title, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: Theme.of(context).colorScheme.primary, title: Text(title), value: value, onChanged: onChanged);
  }
}

class _DropdownTile extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  const _DropdownTile({required this.label, required this.value, required this.items, required this.icon, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.date, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final text = date == null ? '-' : '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}';
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: ListTile(
        leading: const Icon(Icons.cake_outlined, color: Colors.white70),
        title: Text(label),
        subtitle: Text(text),
        trailing: const Icon(Icons.edit_calendar_outlined, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }
}
