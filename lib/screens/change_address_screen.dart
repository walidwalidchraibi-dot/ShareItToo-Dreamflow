import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';

class ChangeAddressScreen extends StatefulWidget {
  const ChangeAddressScreen({super.key});
  @override
  State<ChangeAddressScreen> createState() => _ChangeAddressScreenState();
}

class _ChangeAddressScreenState extends State<ChangeAddressScreen> {
  User? _user;
  bool _loading = true;
  String _error = '';
  final _addrCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final u = await DataService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = u;
      _loading = false;
      _addrCtrl.text = _addressDisplay(u) == '—' ? '' : _addressDisplay(u);
    });
  }

  String _addressDisplay(User? u) {
    if (u == null) return '—';
    final line = (u.homeLocation ?? '').trim();
    if (line.isNotEmpty) return line;
    final city = (u.city ?? '').trim();
    final country = (u.country ?? '').trim();
    if (city.isEmpty && country.isEmpty) return '—';
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }

  bool _hasStreetNumber(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return false;
    final first = raw.split(',').first.trim();
    return RegExp(r"\d").hasMatch(first);
  }

  Future<void> _save() async {
    final line = _addrCtrl.text.trim();
    if (line.isEmpty) {
      setState(() => _error = 'Bitte gib eine Adresse ein');
      return;
    }
    if (!_hasStreetNumber(line)) {
      setState(() => _error = 'Bitte gib Straße und Hausnummer an (z. B. Musterstraße 12)');
      return;
    }
    try {
      final current = await DataService.getCurrentUser();
      if (current == null) {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      final derivedCity = DataService.deriveCityFromAddress(line);
      final updated = current.copyWith(
        homeLocation: line,
        city: derivedCity.isNotEmpty ? derivedCity : current.city,
      );
      await DataService.setCurrentUser(updated);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')));
    } catch (e) {
      debugPrint('[ChangeAddress] save failed: $e');
      setState(() => _error = 'Speichern fehlgeschlagen');
    }
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Text('Adresse ändern'),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: _addrCtrl,
                    keyboardType: TextInputType.streetAddress,
                    autofillHints: const [AutofillHints.streetAddressLine1, AutofillHints.streetAddressLine2, AutofillHints.postalCode, AutofillHints.addressCity],
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.place_outlined), labelText: 'Adresse (Straße und Hausnummer, PLZ, Stadt)', hintText: 'z. B. Musterstraße 12, 12345 Berlin'),
                  ),
                  const SizedBox(height: 12),
                  Text('Nur du und deine Gegenpartei nach Annahme sehen diese Adresse.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_error, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(onPressed: _save, child: const Text('Speichern')),
                ]),
              ),
      ),
    ]);
  }
}
