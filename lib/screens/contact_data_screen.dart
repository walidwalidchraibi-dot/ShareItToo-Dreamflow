import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/approx_location_map.dart';

class ContactDataScreen extends StatefulWidget {
  const ContactDataScreen({super.key});

  @override
  State<ContactDataScreen> createState() => _ContactDataScreenState();
}

class _ContactDataScreenState extends State<ContactDataScreen> {
  final _formKey = GlobalKey<FormState>();

  User? _user;
  bool _loading = true;
  bool _saving = false;

  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  late final TextEditingController _streetCtrl;
  late final TextEditingController _houseNumberCtrl;
  late final TextEditingController _postalCodeCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _extraCtrl;

  String _generalError = '';

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _streetCtrl = TextEditingController();
    _houseNumberCtrl = TextEditingController();
    _postalCodeCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _countryCtrl = TextEditingController();
    _extraCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _streetCtrl.dispose();
    _houseNumberCtrl.dispose();
    _postalCodeCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final u = await DataService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = u;
        _loading = false;
        _generalError = '';
      });
      _hydrateControllersFromUser(u);
    } catch (e) {
      debugPrint('[ContactData] load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _generalError = 'Laden fehlgeschlagen.';
      });
    }
  }

  void _hydrateControllersFromUser(User? u) {
    if (u == null) return;

    _phoneCtrl.text = u.phone ?? '';
    _emailCtrl.text = u.email;

    // Prefer structured fields; fall back to parsing the legacy homeLocation.
    final parsed = _parseLegacyAddress(u.homeLocation ?? '');
    _streetCtrl.text = u.addressStreet ?? parsed.street ?? '';
    _houseNumberCtrl.text = u.addressHouseNumber ?? parsed.houseNumber ?? '';
    _postalCodeCtrl.text = u.addressPostalCode ?? parsed.postalCode ?? '';
    _cityCtrl.text = u.addressCity ?? parsed.city ?? (u.city ?? '');
    _countryCtrl.text = u.addressCountry ?? (u.country ?? '');
    _extraCtrl.text = u.addressExtra ?? '';
  }

  _ParsedAddress _parseLegacyAddress(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return const _ParsedAddress();

    // Very defensive: "Street 12, 12345 City".
    final parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return const _ParsedAddress();

    String? street;
    String? house;
    String? postal;
    String? city;

    final line1 = parts.first;
    final m1 = RegExp(r'^(.*?)(?:\s+)(\d+[a-zA-Z]?)\s*$').firstMatch(line1);
    if (m1 != null) {
      street = m1.group(1)?.trim();
      house = m1.group(2)?.trim();
    } else {
      street = line1;
    }

    if (parts.length >= 2) {
      final line2 = parts[1];
      final m2 = RegExp(r'^(\d{4,10})\s+(.*)$').firstMatch(line2);
      if (m2 != null) {
        postal = m2.group(1)?.trim();
        city = m2.group(2)?.trim();
      } else {
        city = line2;
      }
    }

    return _ParsedAddress(street: street, houseNumber: house, postalCode: postal, city: city);
  }

  bool get _hasRequiredAddressFields {
    return _streetCtrl.text.trim().isNotEmpty &&
        _houseNumberCtrl.text.trim().isNotEmpty &&
        _postalCodeCtrl.text.trim().isNotEmpty &&
        _cityCtrl.text.trim().isNotEmpty &&
        _countryCtrl.text.trim().isNotEmpty;
  }

  String _composeAddressLine() {
    final street = _streetCtrl.text.trim();
    final house = _houseNumberCtrl.text.trim();
    final postal = _postalCodeCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final country = _countryCtrl.text.trim();
    final extra = _extraCtrl.text.trim();
    final line1 = '$street $house'.trim();
    final line2 = '$postal $city'.trim();
    final extraPart = extra.isNotEmpty ? ', $extra' : '';
    return '$line1$extraPart, $line2, $country';
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Bitte gib eine E‑Mail-Adresse ein.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'Bitte gib eine gültige E‑Mail-Adresse ein.';
    return null;
  }

  String? _validatePhone(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Bitte gib eine Telefonnummer ein.';
    // Simple international format check; accepts + and digits.
    final ok = RegExp(r'^\+?[0-9][0-9\s\-()]{6,}$').hasMatch(value);
    if (!ok) return 'Bitte gib eine gültige (internationale) Telefonnummer ein.';
    return null;
  }

  String? _validatePostal(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Postleitzahl ist erforderlich.';
    final ok = RegExp(r'^[0-9A-Za-z\-\s]{4,10}$').hasMatch(value);
    if (!ok) return 'Bitte gib eine gültige Postleitzahl ein.';
    return null;
  }

  String? _required(String label, String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return '$label ist erforderlich.';
    return null;
  }

  Future<void> _save() async {
    setState(() => _generalError = '');
    final current = _user;
    if (current == null) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (!_hasRequiredAddressFields) {
      setState(() => _generalError = 'Bitte vervollständige deine Adresse.');
      return;
    }

    final newEmail = _emailCtrl.text.trim();
    final newPhone = _phoneCtrl.text.trim();
    final addressLine = _composeAddressLine();

    final emailChanged = newEmail != current.email;
    final phoneChanged = newPhone != (current.phone ?? '');

    setState(() => _saving = true);
    try {
      final updated = current.copyWith(
        email: newEmail,
        phone: newPhone,
        emailVerified: emailChanged ? false : current.emailVerified,
        phoneVerified: phoneChanged ? false : current.phoneVerified,
        addressStreet: _streetCtrl.text.trim(),
        addressHouseNumber: _houseNumberCtrl.text.trim(),
        addressPostalCode: _postalCodeCtrl.text.trim(),
        addressCity: _cityCtrl.text.trim(),
        addressCountry: _countryCtrl.text.trim(),
        addressExtra: _extraCtrl.text.trim().isEmpty ? null : _extraCtrl.text.trim(),
        // Keep legacy fields in sync for existing parts of the app.
        homeLocation: addressLine,
        city: _cityCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
      );
      await DataService.setCurrentUser(updated);
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')));
    } catch (e) {
      debugPrint('[ContactData] save failed: $e');
      if (!mounted) return;
      setState(() => _generalError = 'Speichern fehlgeschlagen. Bitte versuche es erneut.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _verifyPhoneFlow() async {
    final phoneError = _validatePhone(_phoneCtrl.text);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }

    final code = (Random().nextInt(900000) + 100000).toString();
    debugPrint('[ContactData] Demo SMS code for ${_phoneCtrl.text.trim()}: $code');

    final codeCtrl = TextEditingController();
    bool verifying = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SheetScaffold(
          title: 'Telefonnummer verifizieren',
          subtitle: 'Wir haben dir einen SMS‑Code gesendet. (Demo‑Code steht im Debug‑Log)',
          child: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'SMS‑Code', prefixIcon: Icon(Icons.sms_outlined)),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: verifying
                      ? null
                      : () async {
                          setLocal(() => verifying = true);
                          try {
                            final entered = codeCtrl.text.trim();
                            if (entered != code) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code ist nicht korrekt.')));
                              return;
                            }
                            final u = _user;
                            if (u == null) return;
                            final updated = u.copyWith(phoneVerified: true);
                            await DataService.setCurrentUser(updated);
                            if (!mounted) return;
                            setState(() => _user = updated);
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telefonnummer verifiziert')));
                          } catch (e) {
                            debugPrint('[ContactData] verify phone failed: $e');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verifizierung fehlgeschlagen.')));
                          } finally {
                            setLocal(() => verifying = false);
                          }
                        },
                  child: verifying ? const _BusyButtonLabel() : const Text('Bestätigen'),
                ),
              ]);
            },
          ),
        );
      },
    );
  }

  Future<void> _verifyEmailFlow() async {
    final emailError = _validateEmail(_emailCtrl.text);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(emailError)));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool confirming = false;
        return _SheetScaffold(
          title: 'E‑Mail bestätigen',
          subtitle: 'Wir haben dir einen Bestätigungslink gesendet. Sobald du ihn geöffnet hast, bestätige hier.',
          child: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Row(children: [
                    Icon(Icons.mail_outline, color: Colors.white.withValues(alpha: 0.85)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_emailCtrl.text.trim(), style: Theme.of(context).textTheme.bodyMedium)),
                  ]),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: confirming
                      ? null
                      : () async {
                          setLocal(() => confirming = true);
                          try {
                            final u = _user;
                            if (u == null) return;
                            final updated = u.copyWith(emailVerified: true);
                            await DataService.setCurrentUser(updated);
                            if (!mounted) return;
                            setState(() => _user = updated);
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E‑Mail bestätigt')));
                          } catch (e) {
                            debugPrint('[ContactData] verify email failed: $e');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bestätigung fehlgeschlagen.')));
                          } finally {
                            setLocal(() => confirming = false);
                          }
                        },
                  child: confirming ? const _BusyButtonLabel() : const Text('Ich habe bestätigt'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tipp: Ohne Backend ist das hier eine Demo‑Bestätigung. Später kann das an echte E‑Mail-Verifizierung gekoppelt werden.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ]);
            },
          ),
        );
      },
    );
  }

  (double, double) _pseudoGeocode(String address) {
    // Deterministic pseudo coordinates from address hash.
    final seed = address.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final r = Random(seed);

    // Rough bounding box around DACH region (privacy-friendly demo).
    final lat = 46.6 + r.nextDouble() * (54.9 - 46.6);
    final lng = 5.9 + r.nextDouble() * (15.2 - 5.9);
    return (lat, lng);
  }

  Future<void> _confirmLocationOnMap() async {
    if (!_hasRequiredAddressFields) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte vervollständige zuerst die Adresse.')));
      return;
    }

    final u = _user;
    if (u == null) return;

    final address = _composeAddressLine();
    final (lat0, lng0) = u.homeLat != null && u.homeLng != null ? (u.homeLat!, u.homeLng!) : _pseudoGeocode(address);

    double lat = lat0;
    double lng = lng0;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SheetScaffold(
          title: 'Standort auf Karte bestätigen',
          subtitle: 'Wir speichern optionale GPS‑Koordinaten, um Entfernungen und Liefergebühren berechnen zu können.',
          child: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ApproxLocationMap(lat: lat, lng: lng, label: 'Dein Standort (ungefähr)'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final (a, b) = _pseudoGeocode('${address}_${DateTime.now().microsecondsSinceEpoch}');
                        setLocal(() {
                          lat = a;
                          lng = b;
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      label: const Text('Neu berechnen', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setLocal(() => saving = true);
                              try {
                                final current = _user;
                                if (current == null) return;
                                final updated = current.copyWith(homeLat: lat, homeLng: lng);
                                await DataService.setCurrentUser(updated);
                                if (!mounted) return;
                                setState(() => _user = updated);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Standort gespeichert')));
                              } catch (e) {
                                debugPrint('[ContactData] save coords failed: $e');
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Speichern fehlgeschlagen.')));
                              } finally {
                                setLocal(() => saving = false);
                              }
                            },
                      child: saving ? const _BusyButtonLabel() : const Text('Speichern'),
                    ),
                  ),
                ]),
              ]);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final theme = Theme.of(context);

    return Stack(children: [
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
      ),
      Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text('Kontaktinformationen'),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                top: false,
                child: Column(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 18, 16, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('Kontaktinformationen', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            'Diese Informationen werden für Kommunikation, Verifizierung sowie für Übergaben, Rückgaben und mögliche Lieferungen verwendet. Deine Daten sind nicht öffentlich sichtbar.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45),
                          ),
                          if (_generalError.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _InlineError(text: _generalError),
                          ],
                          const SizedBox(height: 18),

                          _SectionHeader(title: 'Telefonnummer'),
                          const SizedBox(height: 10),
                          _SectionCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                autofillHints: const [AutofillHints.telephoneNumber],
                                validator: _validatePhone,
                                decoration: const InputDecoration(
                                  labelText: 'Telefonnummer',
                                  hintText: '+49 151 23456789',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _VerifyStatusRow(
                                verified: user?.phoneVerified ?? false,
                                verifiedLabel: 'Verifiziert',
                                unverifiedLabel: 'Nicht verifiziert',
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: (user?.phoneVerified ?? false) ? null : _verifyPhoneFlow,
                                icon: const Icon(Icons.verified_outlined, color: Colors.white),
                                label: const Text('Telefonnummer verifizieren', style: TextStyle(color: Colors.white)),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 18),

                          _SectionHeader(title: 'E‑Mail‑Adresse'),
                          const SizedBox(height: 10),
                          _SectionCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                validator: _validateEmail,
                                decoration: const InputDecoration(labelText: 'E‑Mail‑Adresse', prefixIcon: Icon(Icons.alternate_email)),
                              ),
                              const SizedBox(height: 10),
                              _VerifyStatusRow(
                                verified: user?.emailVerified ?? false,
                                verifiedLabel: 'Verifiziert',
                                unverifiedLabel: 'Nicht verifiziert',
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: (user?.emailVerified ?? false) ? null : _verifyEmailFlow,
                                icon: const Icon(Icons.mark_email_read_outlined, color: Colors.white),
                                label: const Text('E‑Mail bestätigen', style: TextStyle(color: Colors.white)),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 18),

                          _SectionHeader(title: 'Adresse'),
                          const SizedBox(height: 8),
                          Text(
                            'Die Adresse ist verpflichtend, da sie für Übergaben, Rückgaben, Lieferungen und die Berechnung möglicher Liefergebühren benötigt wird.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45),
                          ),
                          const SizedBox(height: 10),
                          _SectionCard(
                            child: Column(children: [
                              Row(children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _streetCtrl,
                                    textInputAction: TextInputAction.next,
                                    validator: (v) => _required('Straße', v),
                                    decoration: const InputDecoration(labelText: 'Straße', prefixIcon: Icon(Icons.signpost_outlined)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _houseNumberCtrl,
                                    textInputAction: TextInputAction.next,
                                    validator: (v) => _required('Hausnummer', v),
                                    decoration: const InputDecoration(labelText: 'Hausnummer'),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _postalCodeCtrl,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.text,
                                    validator: _validatePostal,
                                    decoration: const InputDecoration(labelText: 'Postleitzahl', prefixIcon: Icon(Icons.local_post_office_outlined)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _cityCtrl,
                                    textInputAction: TextInputAction.next,
                                    validator: (v) => _required('Stadt', v),
                                    decoration: const InputDecoration(labelText: 'Stadt'),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _countryCtrl,
                                textInputAction: TextInputAction.next,
                                validator: (v) => _required('Land', v),
                                decoration: const InputDecoration(labelText: 'Land', prefixIcon: Icon(Icons.public_outlined)),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _extraCtrl,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(labelText: 'Adresszusatz (optional)', prefixIcon: Icon(Icons.apartment_outlined)),
                              ),
                              const SizedBox(height: 14),
                              if (_hasRequiredAddressFields)
                                OutlinedButton.icon(
                                  onPressed: _confirmLocationOnMap,
                                  icon: const Icon(Icons.map_outlined, color: Colors.white),
                                  label: const Text('Standort auf Karte bestätigen', style: TextStyle(color: Colors.white)),
                                ),
                              if (!_hasRequiredAddressFields)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Standortbestätigung ist optional (verfügbar, sobald die Pflichtfelder ausgefüllt sind).',
                                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                                  ),
                                ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          _PrivacyNote(
                            text:
                                'Deine Adresse wird nur für Buchungen, Übergaben, Rückgaben und mögliche Lieferungen verwendet. Sie ist nicht öffentlich sichtbar.\n\nDie genaue Adresse wird bei Buchungen erst kurz vor der Übergabe oder Rückgabe angezeigt (je nach Buchungsart).',
                          ),
                          const SizedBox(height: 80),
                        ]),
                      ),
                    ),
                  ),
                  _BottomSaveBar(
                    saving: _saving,
                    onSave: _saving ? null : _save,
                  ),
                ]),
              ),
      ),
    ]);
  }
}

class _ParsedAddress {
  final String? street;
  final String? houseNumber;
  final String? postalCode;
  final String? city;
  const _ParsedAddress({this.street, this.houseNumber, this.postalCode, this.city});
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 0.2));
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }
}

class _VerifyStatusRow extends StatelessWidget {
  final bool verified;
  final String verifiedLabel;
  final String unverifiedLabel;
  const _VerifyStatusRow({required this.verified, required this.verifiedLabel, required this.unverifiedLabel});

  @override
  Widget build(BuildContext context) {
    final bg = verified ? BrandColors.success.withValues(alpha: 0.18) : BrandColors.danger.withValues(alpha: 0.18);
    final border = verified ? BrandColors.success.withValues(alpha: 0.35) : BrandColors.danger.withValues(alpha: 0.35);
    final icon = verified ? Icons.check_circle_rounded : Icons.error_outline_rounded;
    final text = verified ? verifiedLabel : unverifiedLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Row(children: [
        Icon(icon, size: 18, color: verified ? BrandColors.success : BrandColors.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white))),
      ]),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  final String text;
  const _PrivacyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lock_outline_rounded, color: Colors.white.withValues(alpha: 0.85), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45))),
      ]),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String text;
  const _InlineError({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandColors.danger.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.danger.withValues(alpha: 0.30)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white))),
      ]),
    );
  }
}

class _BottomSaveBar extends StatelessWidget {
  final bool saving;
  final VoidCallback? onSave;
  const _BottomSaveBar({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: onSave,
            child: saving ? const _BusyButtonLabel() : const Text('Änderungen speichern'),
          ),
        ),
      ),
    );
  }
}

class _BusyButtonLabel extends StatelessWidget {
  const _BusyButtonLabel();

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      SizedBox(width: 10),
      Text('Bitte warten…'),
    ]);
  }
}

class _SheetScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _SheetScaffold({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                  tooltip: 'Schließen',
                ),
              ]),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45)),
              const SizedBox(height: 14),
              child,
            ]),
          ),
        ),
      ),
    );
  }
}
