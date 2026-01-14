import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/maps_service.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/approx_location_map.dart';

class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});
  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  User? _user;

  // Local editable state
  String _workTitle = '';
  DateTime? _birthDate;
  String _addressLine = '';
  double? _lat;
  double? _lng;
  List<String> _languages = [];
  List<String> _interests = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await DataService.getCurrentUser();
    setState(() {
      _user = u;
      _workTitle = u?.workTitle ?? '';
      _birthDate = u?.birthDate;
      _addressLine = u?.homeLocation ?? _formatCityCountry(u?.city, u?.country);
      _lat = u?.homeLat;
      _lng = u?.homeLng;
      _languages = List<String>.from(u?.languages ?? const []);
      // Merge old hobbies string into interests chips on first load
      final baseInterests = List<String>.from(u?.interests ?? const []);
      final hobbies = (u?.hobbies ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      final merged = {...baseInterests, ...hobbies}.toList();
      _interests = merged;
    });
  }

  bool get _dirty {
    final u = _user;
    if (u == null) return false;
    if ((_workTitle.trim()) != (u.workTitle ?? '')) return true;
    if (!_isSameDate(_birthDate, u.birthDate)) return true;
    if ((_addressLine.trim()) != (u.homeLocation ?? _formatCityCountry(u.city, u.country))) return true;
    if ((_lat ?? double.nan) != (u.homeLat ?? double.nan)) return true;
    if ((_lng ?? double.nan) != (u.homeLng ?? double.nan)) return true;
    if (!_listEquals(_languages, u.languages)) return true;
    if (!_listEquals(_interests, u.interests)) return true;
    return false;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _formatCityCountry(String? city, String? country) {
    if ((city ?? '').isEmpty && (country ?? '').isEmpty) return '';
    if ((city ?? '').isEmpty) return country ?? '';
    if ((country ?? '').isEmpty) return city ?? '';
    return '${city!}, ${country!}';
  }

  Future<void> _save() async {
    if (_user == null || !_dirty) return;
    setState(() => _saving = true);
    try {
      // Heuristic city/country parsing from address line when possible
      final parsed = _parseCityCountry(_addressLine);
      final updated = _user!.copyWith(
        workTitle: _workTitle.trim().isEmpty ? null : _workTitle.trim(),
        birthDate: _birthDate,
        homeLocation: _addressLine.trim().isEmpty ? null : _addressLine.trim(),
        homeLat: _lat,
        homeLng: _lng,
        city: parsed.$1.isNotEmpty ? parsed.$1 : _user!.city,
        country: parsed.$2.isNotEmpty ? parsed.$2 : _user!.country,
        interests: List<String>.from(_interests),
        languages: List<String>.from(_languages),
      );
      await DataService.setCurrentUser(updated);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')));
    } catch (e) {
      debugPrint('[ProfileInfo] save failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Speichern fehlgeschlagen')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  (String, String) _parseCityCountry(String line) {
    final parts = line.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 2) {
      final country = parts.last;
      final city = parts[parts.length - 2];
      return (city, country);
    }
    return ('', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text('Profilinformationen'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: AppGradientBackground(
        child: Stack(children: [
          Positioned.fill(child: _buildScrollContent()),
          _BottomSaveBar(enabled: _dirty && !_saving, saving: _saving, onSave: _save),
        ]),
      ),
    );
  }

  Widget _buildScrollContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _GlassCard(title: 'Persönliche Angaben', child: _PersonalCard(
          workTitle: _workTitle,
          birthDate: _birthDate,
          onWorkChanged: (v) => setState(() => _workTitle = v),
          onBirthChanged: (d) => setState(() => _birthDate = d),
        )),
        const SizedBox(height: 16),
        _GlassCard(title: 'Standort', child: _LocationCard(
          addressLine: _addressLine,
          lat: _lat,
          lng: _lng,
          onPick: (line, lat, lng) => setState(() { _addressLine = line; _lat = lat; _lng = lng; }),
        )),
        const SizedBox(height: 16),
        _GlassCard(title: 'Sprachen', child: _LanguagesCard(
          languages: _languages,
          onChanged: (list) => setState(() => _languages = list),
        )),
        const SizedBox(height: 16),
        _GlassCard(title: 'Interessen & Hobbys', child: _InterestsCard(
          interests: _interests,
          onChanged: (list) => setState(() => _interests = list),
        )),
        const SizedBox(height: 24),
      ]),
    );
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _GlassCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _GlassCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.person_outline, color: Colors.white70),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              child,
            ]),
          ),
        ),
      ),
    );
  }
}

class _PersonalCard extends StatefulWidget {
  final String workTitle;
  final DateTime? birthDate;
  final ValueChanged<String> onWorkChanged;
  final ValueChanged<DateTime?> onBirthChanged;
  const _PersonalCard({required this.workTitle, required this.birthDate, required this.onWorkChanged, required this.onBirthChanged});
  @override
  State<_PersonalCard> createState() => _PersonalCardState();
}

class _PersonalCardState extends State<_PersonalCard> {
  bool _editWork = false;
  bool _editBirth = false;
  late final TextEditingController _workCtrl = TextEditingController(text: widget.workTitle);

  @override
  void didUpdateWidget(covariant _PersonalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workTitle != widget.workTitle && !_editWork) {
      _workCtrl.text = widget.workTitle;
    }
  }

  @override
  void dispose() { _workCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      _InlineField(
        icon: Icons.work_outline,
        label: 'Beruf',
        display: (widget.workTitle.isEmpty) ? Text('z. B. Produktdesigner', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38)) : Text(widget.workTitle),
        editor: TextField(
          controller: _workCtrl,
          autofocus: true,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Dein Beruf (optional)'),
          onChanged: widget.onWorkChanged,
        ),
        editing: _editWork,
        onToggle: () => setState(() => _editWork = !_editWork),
      ),
      const SizedBox(height: 8),
      _InlineField(
        icon: Icons.cake_outlined,
        label: 'Geburtsdatum',
        display: (widget.birthDate == null)
            ? Text('Tippen, um zu wählen', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38))
            : Text('${widget.birthDate!.day.toString().padLeft(2, '0')}.${widget.birthDate!.month.toString().padLeft(2, '0')}.${widget.birthDate!.year}'),
        editor: _DatePickerInline(
          initial: widget.birthDate,
          onPicked: (d) { widget.onBirthChanged(d); setState(() => _editBirth = false); },
        ),
        editing: _editBirth,
        onToggle: () async {
          if (_editBirth) { setState(() => _editBirth = false); return; }
          setState(() => _editBirth = true);
        },
      ),
    ]);
  }
}

class _DatePickerInline extends StatelessWidget {
  final DateTime? initial; final ValueChanged<DateTime?> onPicked;
  const _DatePickerInline({required this.initial, required this.onPicked});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year - 100);
    final last = now;
    return Row(children: [
      Expanded(child: FilledButton.icon(onPressed: () async {
        final picked = await showDatePicker(context: context, firstDate: first, lastDate: last, initialDate: initial ?? DateTime(now.year - 25));
        onPicked(picked);
      }, icon: const Icon(Icons.calendar_month), label: Text(initial == null ? 'Datum wählen' : 'Ändern'))),
      const SizedBox(width: 8),
      if (initial != null)
        IconButton(onPressed: () => onPicked(null), icon: const Icon(Icons.close)),
    ]);
  }
}

class _InlineField extends StatelessWidget {
  final IconData icon; final String label; final Widget display; final Widget editor; final bool editing; final VoidCallback onToggle;
  const _InlineField({required this.icon, required this.label, required this.display, required this.editor, required this.editing, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: editing ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Row(children: [Icon(icon, color: Colors.white70), const SizedBox(width: 8), Expanded(child: display)]),
          secondChild: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, color: Colors.white70), const SizedBox(width: 8), Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70))]),
            const SizedBox(height: 8),
            editor,
          ]),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String addressLine; final double? lat; final double? lng; final void Function(String, double?, double?) onPick;
  const _LocationCard({required this.addressLine, required this.lat, required this.lng, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if ((addressLine).isNotEmpty || (lat != null && lng != null)) ...[
        ClipRRect(borderRadius: BorderRadius.circular(12), child: ApproxLocationMap(lat: lat, lng: lng, label: (addressLine.isNotEmpty ? addressLine : 'Dein Standort'), height: 220)),
        const SizedBox(height: 8),
      ],
      GestureDetector(
        onTap: () => _openPicker(context),
        child: Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(children: [
            const Icon(Icons.place_outlined, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(child: Text(addressLine.isEmpty ? 'Leipzig, Deutschland' : addressLine, style: theme.textTheme.bodyMedium)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ]),
        ),
      ),
    ]);
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.7),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _LocationPickerSheet(
        initialAddress: addressLine,
        initialLat: lat,
        initialLng: lng,
        onConfirm: onPick,
      ),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  final String initialAddress; final double? initialLat; final double? initialLng; final void Function(String, double?, double?) onConfirm;
  const _LocationPickerSheet({required this.initialAddress, required this.initialLat, required this.initialLng, required this.onConfirm});
  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _suggestions = [];
  String _address = '';
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _address = widget.initialAddress;
    _lat = widget.initialLat;
    _lng = widget.initialLng;
    _searchCtrl.text = widget.initialAddress;
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Adresse suchen'),
              onChanged: _query,
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
              itemBuilder: (context, i) {
                final s = _suggestions[i];
                return ListTile(
                  leading: const Icon(Icons.place_outlined, color: Colors.white70),
                  title: Text(s, style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    String line = s;
                    double? lat; double? lng;
                    try {
                      // Try to enrich with place details when possible
                      final opts = await MapsService.autocomplete(s);
                      if (opts.isNotEmpty && opts.first.placeId != null) {
                        final det = await MapsService.placeDetails(opts.first.placeId!);
                        if (det != null) { line = det.formattedAddress; lat = det.lat; lng = det.lng; }
                      }
                    } catch (e) { debugPrint('[LocationPicker] details failed: $e'); }
                    setState(() { _address = line; _lat = lat; _lng = lng; });
                    // Collapse suggestions
                    setState(() { _suggestions = []; });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (_address.isNotEmpty || (_lat != null && _lng != null)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ApproxLocationMap(lat: _lat, lng: _lng, label: _address.isNotEmpty ? _address : 'Standort', height: 200),
              ),
            ),
            const SizedBox(height: 8),
            if (_lat != null && _lng != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Text('Position feintunen:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 8),
                  _NudgeButton(icon: Icons.keyboard_arrow_up, onTap: () => setState(() => _lat = _lat! + 0.0005)),
                  _NudgeButton(icon: Icons.keyboard_arrow_down, onTap: () => setState(() => _lat = _lat! - 0.0005)),
                  _NudgeButton(icon: Icons.keyboard_arrow_left, onTap: () => setState(() => _lng = _lng! - 0.0005)),
                  _NudgeButton(icon: Icons.keyboard_arrow_right, onTap: () => setState(() => _lng = _lng! + 0.0005)),
                ]),
              ),
            const SizedBox(height: 12),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(child: FilledButton(onPressed: () { widget.onConfirm(_address, _lat, _lng); Navigator.of(context).maybePop(); }, child: const Text('Übernehmen'))),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _query(String q) async {
    q = q.trim();
    if (q.isEmpty) { setState(() => _suggestions = []); return; }
    try {
      final opts = await MapsService.autocomplete(q, language: 'de', country: 'de');
      setState(() => _suggestions = opts.map((e) => e.description).toList());
    } catch (e) { debugPrint('[LocationPicker] autocomplete failed: $e'); }
  }
}

class _NudgeButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; const _NudgeButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 18, color: Colors.white))),
      ),
    );
  }
}

class _LanguagesCard extends StatelessWidget {
  final List<String> languages; final ValueChanged<List<String>> onChanged;
  const _LanguagesCard({required this.languages, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in languages)
          _RemovableChip(label: l, onRemove: () { final list = List<String>.from(languages)..remove(l); onChanged(list); }),
        _AddChip(label: '+ Sprache hinzufügen', onTap: () => _openSheet(context)),
      ]),
    ]);
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.7),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _LanguagePicker(
        initial: languages,
        onDone: (list) => onChanged(list),
      ),
    );
  }
}

class _LanguagePicker extends StatefulWidget {
  final List<String> initial; final ValueChanged<List<String>> onDone;
  const _LanguagePicker({required this.initial, required this.onDone});
  @override
  State<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<_LanguagePicker> {
  final TextEditingController _search = TextEditingController();
  late List<String> _picked = List<String>.from(widget.initial);
  static const List<String> _all = [
    'Deutsch','Englisch','Französisch','Italienisch','Spanisch','Arabisch','Türkisch','Niederländisch','Polnisch','Russisch','Portugiesisch','Griechisch','Rumänisch','Schwedisch','Norwegisch','Dänisch','Finnisch','Tschechisch','Ungarisch'
  ];
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final list = _all.where((e) => e.toLowerCase().contains(q)).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _search, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Sprache suchen'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (context, i) {
                final l = list[i];
                final selected = _picked.contains(l);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (_) => setState(() { if (selected) { _picked.remove(l); } else { _picked.add(l); } }),
                  title: Text(l, style: const TextStyle(color: Colors.white)),
                  activeColor: Theme.of(context).colorScheme.primary,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: FilledButton(onPressed: () { widget.onDone(_picked); Navigator.of(context).maybePop(); }, child: const Text('Übernehmen')))]),
        ]),
      ),
    );
  }
}

class _InterestsCard extends StatelessWidget {
  final List<String> interests; final ValueChanged<List<String>> onChanged;
  const _InterestsCard({required this.interests, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final i in interests)
          _RemovableChip(label: i, onRemove: () { final list = List<String>.from(interests)..remove(i); onChanged(list); }),
        _AddChip(label: '+ Hinzufügen', onTap: () => _openSheet(context)),
      ]),
    ]);
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.7),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _InterestPicker(initial: interests, onDone: (sel) => onChanged(sel)),
    );
  }
}

class _InterestPicker extends StatefulWidget {
  final List<String> initial; final ValueChanged<List<String>> onDone;
  const _InterestPicker({required this.initial, required this.onDone});
  @override
  State<_InterestPicker> createState() => _InterestPickerState();
}

class _InterestPickerState extends State<_InterestPicker> {
  final TextEditingController _search = TextEditingController();
  late List<String> _picked = List<String>.from(widget.initial);
  static const List<String> _suggestions = [
    'Technik','Fotografie','Fitness','Outdoor','Gaming','Kochen','Reisen','Musik','Kunst','DIY','Lesen','Mode','Garten','Fahrrad','Haustiere','Autos','Film & Serien','Sprachen','Startups'
  ];
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final list = _suggestions.where((e) => e.toLowerCase().contains(q)).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _search, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Interessen suchen'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in list)
              ChoiceChip(
                label: Text(s),
                selected: _picked.contains(s),
                onSelected: (_) => setState(() { if (_picked.contains(s)) { _picked.remove(s); } else { _picked.add(s); } }),
                labelStyle: const TextStyle(color: Colors.white),
                selectedColor: BrandColors.logoAccent.withValues(alpha: 0.25),
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
          ])),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: FilledButton(onPressed: () { widget.onDone(_picked); Navigator.of(context).maybePop(); }, child: const Text('Übernehmen')))]),
        ]),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  final String label; final VoidCallback onRemove;
  const _RemovableChip({required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(width: 8),
        InkWell(onTap: onRemove, borderRadius: BorderRadius.circular(999), child: const Icon(Icons.close, size: 16, color: Colors.white70)),
      ]),
    );
  }
}

class _AddChip extends StatelessWidget {
  final String label; final VoidCallback onTap; const _AddChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.add, size: 18, color: Colors.white), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white))]))),
    );
  }
}

class _BottomSaveBar extends StatelessWidget {
  final bool enabled; final bool saving; final VoidCallback onSave; const _BottomSaveBar({required this.enabled, required this.saving, required this.onSave});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.35)]),
          ),
          child: Row(children: [
            Expanded(child: FilledButton(onPressed: enabled ? onSave : null, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Speichern'))),
          ]),
        ),
      ),
    );
  }
}
