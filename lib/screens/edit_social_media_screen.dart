import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';

class EditSocialMediaScreen extends StatefulWidget {
  const EditSocialMediaScreen({super.key});
  @override
  State<EditSocialMediaScreen> createState() => _EditSocialMediaScreenState();
}

class _EditSocialMediaScreenState extends State<EditSocialMediaScreen> {
  User? _user;
  bool _loading = true;
  String _error = '';

  final _xCtrl = TextEditingController();
  final _igCtrl = TextEditingController();
  final _fbCtrl = TextEditingController();
  final _ttCtrl = TextEditingController();
  final _scCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _xCtrl.dispose();
    _igCtrl.dispose();
    _fbCtrl.dispose();
    _ttCtrl.dispose();
    _scCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final u = await DataService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = u;
      _loading = false;
      _xCtrl.text = u?.socialX ?? '';
      _igCtrl.text = u?.socialInstagram ?? '';
      _fbCtrl.text = u?.socialFacebook ?? '';
      _ttCtrl.text = u?.socialTiktok ?? '';
      _scCtrl.text = u?.socialSnapchat ?? '';
    });
  }

  String _norm(String platform, String input) {
    String v = input.trim();
    if (v.isEmpty) return '';
    v = v.replaceAll('\n', ' ').split(' ').first.trim();
    if (v.startsWith('@')) v = v.substring(1);
    bool looksUrl = v.startsWith('http://') || v.startsWith('https://');
    switch (platform) {
      case 'x':
        if (v.contains('twitter.com')) v = v.replaceAll('twitter.com', 'x.com');
        if (looksUrl) return v;
        return 'https://x.com/$v';
      case 'instagram':
        if (looksUrl) return v;
        return 'https://instagram.com/$v';
      case 'facebook':
        if (looksUrl) return v;
        return 'https://facebook.com/$v';
      case 'tiktok':
        if (looksUrl) return v;
        final h = v.startsWith('@') ? v.substring(1) : v;
        return 'https://www.tiktok.com/@$h';
      case 'snapchat':
        if (looksUrl) return v;
        return 'https://www.snapchat.com/add/$v';
      default:
        return v;
    }
  }

  Future<void> _save() async {
    final x = _norm('x', _xCtrl.text);
    final ig = _norm('instagram', _igCtrl.text);
    final fb = _norm('facebook', _fbCtrl.text);
    final tt = _norm('tiktok', _ttCtrl.text);
    final sc = _norm('snapchat', _scCtrl.text);
    try {
      final current = await DataService.getCurrentUser();
      if (current == null) {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      final updated = current.copyWith(
        socialX: x.isEmpty ? null : x,
        socialInstagram: ig.isEmpty ? null : ig,
        socialFacebook: fb.isEmpty ? null : fb,
        socialTiktok: tt.isEmpty ? null : tt,
        socialSnapchat: sc.isEmpty ? null : sc,
      );
      await DataService.setCurrentUser(updated);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')));
    } catch (e) {
      debugPrint('[EditSocialMedia] save failed: $e');
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
          title: const Text('Social Media hinzufügen'),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: _xCtrl,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset('assets/images/X_social_media_app_icon_2025_black_logo_null_1770586094871.jpg', width: 24, height: 24, fit: BoxFit.cover),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      labelText: 'X (Twitter)',
                      hintText: 'z. B. @deinname oder https://x.com/deinname',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _igCtrl,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset('assets/images/Instagram_app_icon_2025_gradient_logo_square_null_1770571531306.png', width: 24, height: 24, fit: BoxFit.cover),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      labelText: 'Instagram',
                      hintText: 'z. B. @deinname oder instagram.com/deinname',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fbCtrl,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset('assets/images/Facebook_app_icon_2025_blue_logo_square_null_1770571533016.png', width: 24, height: 24, fit: BoxFit.cover),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      labelText: 'Facebook',
                      hintText: 'Profil/Seite URL oder Handle',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ttCtrl,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset('assets/images/TikTok_app_icon_2025_colorful_logo_square_null_1770571534194.png', width: 24, height: 24, fit: BoxFit.cover),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      labelText: 'TikTok',
                      hintText: 'z. B. @deinname oder tiktok.com/@deinname',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _scCtrl,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset('assets/images/Snapchat_app_icon_2025_yellow_ghost_logo_square_null_1770571535012.png', width: 24, height: 24, fit: BoxFit.cover),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      labelText: 'Snapchat',
                      hintText: 'z. B. deinusername oder snapchat.com/add/deinusername',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Diese Links können auf deinem öffentlichen Profil erscheinen.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
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
