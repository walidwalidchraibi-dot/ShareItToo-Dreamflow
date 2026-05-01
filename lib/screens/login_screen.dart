import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lendify/navigation/main_navigation.dart';
import 'package:lendify/navigation/main_nav_controller.dart';
import 'package:lendify/screens/register_screen.dart';
import 'package:lendify/services/auth_service.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/developer_preview_service.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/widgets/sit_logo_header.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/widgets/blur_modal.dart';
import 'package:lendify/widgets/social_auth_button.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  final int? returnTabIndex;
  const LoginScreen({super.key, this.returnTabIndex});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardKey = GlobalKey();

  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _pwFocus = FocusNode();

  bool _busy = false;
  bool _checkingSession = true;
  bool _pwVisible = false;
  bool _peekBackdrop = false;

  void _exitToExplore() {
    try {
      context.read<MainNavController>().setIndex(0);
    } catch (_) {
      // If provider isn't available, just navigate.
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  Future<void> _continueAsGuest() async {
    try {
      await AuthService.clearSession();
      await DataService.clearCurrentUser();
      if (!mounted) return;
      await context
          .read<DeveloperPreviewController>()
          .setState(DeveloperUserState.loggedOut);
    } catch (e) {
      debugPrint('[LoginScreen] continueAsGuest failed: $e');
    }
    if (!mounted) return;
    _exitToExplore();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final preview = context.read<DeveloperPreviewController>();

      // Only skip this screen when there is a real persisted session that can
      // still be resolved to a current user in the local dataset.
      final session = await AuthService.readSession();
      if (!mounted) return;

      if (session != null) {
        await DataService.syncCurrentUserForSessionEmail(session.email);
        final resolvedUser = await DataService.getCurrentUser();
        if (!mounted) return;

        if (resolvedUser != null) {
          if (preview.state != DeveloperUserState.loggedIn &&
              preview.state != DeveloperUserState.verifiedUser) {
            await preview.setState(DeveloperUserState.loggedIn);
          }
          if (!mounted) return;
          _goHome(replace: true);
          return;
        }

        debugPrint(
            '[LoginScreen] stale session found for ${session.email}; clearing and staying on login.');
        await AuthService.clearSession();
      }

      // If the preview says "logged in" but there is no valid session, keep the user here.
      if (preview.state == DeveloperUserState.loggedIn ||
          preview.state == DeveloperUserState.verifiedUser) {
        debugPrint(
            '[LoginScreen] preview state indicates logged-in but no valid session found; staying on login.');
      }
    } catch (e) {
      debugPrint('[LoginScreen] bootstrap failed: $e');
    } finally {
      if (mounted) setState(() => _checkingSession = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _emailFocus.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  bool _isOutsideCard(Offset globalPosition) {
    final ctx = _cardKey.currentContext;
    if (ctx == null) return true;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return true;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    return !rect.contains(globalPosition);
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Bitte gib eine gültige E-Mail-Adresse ein.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'Bitte gib eine gültige E-Mail-Adresse ein.';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = (v ?? '');
    if (value.trim().isEmpty) return 'Bitte gib dein Passwort ein.';
    if (value.length < 8) return 'Das Passwort ist zu kurz.';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _busy = true);
    try {
      // Simulate realistic latency.
      await Future<void>.delayed(const Duration(milliseconds: 520));

      final result = await AuthService.signInWithEmailPassword(
          email: _emailCtrl.text, password: _pwCtrl.text);
      if (!mounted) return;

      if (!result.ok) {
        final msg = switch (result.failure) {
          AuthFailure.invalidCredentials =>
            'E-Mail oder Passwort ist nicht korrekt.',
          AuthFailure.network =>
            'Es ist ein Netzwerkfehler aufgetreten. Bitte versuche es erneut.',
          _ => 'Es ist ein Fehler aufgetreten. Bitte versuche es erneut.',
        };
        await AppPopup.toast(context,
            icon: Icons.error_outline,
            title: msg,
            message: 'Tipp: Demo-Login: ${AuthService.demoEmail}');
        return;
      }

      await DataService.syncCurrentUserForSessionEmail(_emailCtrl.text.trim());
      await context
          .read<DeveloperPreviewController>()
          .setState(DeveloperUserState.loggedIn);
      if (!mounted) return;
      _goHome(replace: true);
    } catch (e) {
      debugPrint('[LoginScreen] submit failed: $e');
      if (!mounted) return;
      await AppPopup.toast(context,
          icon: Icons.wifi_off_outlined,
          title: 'Es ist ein Netzwerkfehler aufgetreten.',
          message: 'Bitte versuche es erneut.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goHome({required bool replace}) {
    final targetIndex = widget.returnTabIndex;
    if (targetIndex != null) {
      try {
        context.read<MainNavController>().setIndex(targetIndex);
      } catch (_) {}
    }
    final route = MaterialPageRoute(builder: (_) => MainNavigation(initialIndex: targetIndex ?? 0));
    if (replace) {
      Navigator.of(context).pushAndRemoveUntil(route, (r) => false);
    } else {
      Navigator.of(context).push(route);
    }
  }

  Future<void> _openResetFlow() async {
    final prefill = _emailCtrl.text.trim();
    await showBlurBottomSheet<void>(
      context,
      child: SheetScaffold(
        title: 'Passwort zurücksetzen',
        body: _PasswordResetSheet(initialEmail: prefill),
      ),
    );
  }

  Future<void> _socialSignIn(AuthSocialProvider provider) async {
    if (_busy || !mounted) return;
    final providerLabel =
        provider == AuthSocialProvider.google ? 'Google' : 'Apple';
    await AppPopup.toast(
      context,
      icon: Icons.info_outline,
      title: '$providerLabel-Anmeldung noch nicht verfügbar',
      message: 'Bitte nutze aktuell die Anmeldung per E-Mail.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
                child: IgnorePointer(
                    child: _AuthBackdrop(peekClear: _peekBackdrop))),
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  if (_checkingSession) return;
                  if (_isOutsideCard(e.position))
                    setState(() => _peekBackdrop = true);
                },
                onPointerUp: (_) {
                  if (_peekBackdrop) setState(() => _peekBackdrop = false);
                },
                onPointerCancel: (_) {
                  if (_peekBackdrop) setState(() => _peekBackdrop = false);
                },
                child: IgnorePointer(
                  ignoring: _checkingSession,
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  _GlassIconButton(
                                      icon: Icons.arrow_back,
                                      onTap: () =>
                                          Navigator.of(context).maybePop()),
                                  Expanded(
                                    child: Center(
                                      child: Text('Anmelden',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(width: 44),
                                ]),
                                const SizedBox(height: 22),
                                Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 520),
                                    child: Text(
                                      'Melde dich an, um Dinge zu teilen, zu mieten und deine Buchungen zu verwalten.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              color: Colors.white,
                                              height: 1.35,
                                              fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                    height:
                                        mathMax(18, media.size.height * 0.04)),
                              ]),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            mathMax(
                                18, media.viewInsets.bottom == 0 ? 28 : 12)),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOut,
                                opacity: _peekBackdrop ? 0.22 : 1.0,
                                child: KeyedSubtree(
                                  key: _cardKey,
                                  child: _GlassCard(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 16, 16, 16),
                                      child: Form(
                                        key: _formKey,
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const SitLogoHeader(),
                                              const SizedBox(height: 16),
                                              _SITTextField(
                                                label: 'E-Mail',
                                                placeholder: 'deine@email.com',
                                                controller: _emailCtrl,
                                                focusNode: _emailFocus,
                                                nextFocusNode: _pwFocus,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                textInputAction:
                                                    TextInputAction.next,
                                                validator: _validateEmail,
                                                prefixIcon:
                                                    Icons.alternate_email,
                                                autocorrect: false,
                                                enableSuggestions: false,
                                                textCapitalization:
                                                    TextCapitalization.none,
                                              ),
                                              const SizedBox(height: 12),
                                              _SITTextField(
                                                label: 'Passwort',
                                                placeholder: '••••••••',
                                                controller: _pwCtrl,
                                                focusNode: _pwFocus,
                                                keyboardType: TextInputType
                                                    .visiblePassword,
                                                textInputAction:
                                                    TextInputAction.done,
                                                validator: _validatePassword,
                                                prefixIcon: Icons.lock_outline,
                                                obscureText: !_pwVisible,
                                                autocorrect: false,
                                                enableSuggestions: false,
                                                textCapitalization:
                                                    TextCapitalization.none,
                                                onSubmitted: (_) => _submit(),
                                                suffix: _GlassSuffixIconButton(
                                                  icon: _pwVisible
                                                      ? Icons
                                                          .visibility_off_outlined
                                                      : Icons
                                                          .visibility_outlined,
                                                  onTap: () => setState(() =>
                                                      _pwVisible = !_pwVisible),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: _TextLink(
                                                      label:
                                                          'Passwort vergessen?',
                                                      onTap: _openResetFlow)),
                                              const SizedBox(height: 14),
                                              _PrimaryAuthButton(
                                                  busy: _busy,
                                                  label: _busy
                                                      ? 'Anmelden…'
                                                      : 'Anmelden',
                                                  icon: Icons.login,
                                                  onTap:
                                                      _busy ? null : _submit),
                                              const SizedBox(height: 14),
                                              const SocialAuthOrDivider(),
                                              const SizedBox(height: 12),
                                              SocialAuthButton(
                                                  brand: SocialAuthBrand.google,
                                                  label: 'Mit Google anmelden',
                                                  onTap: _busy
                                                      ? null
                                                      : () => _socialSignIn(
                                                          AuthSocialProvider
                                                              .google)),
                                              const SizedBox(height: 10),
                                              SocialAuthButton(
                                                  brand: SocialAuthBrand.apple,
                                                  label: 'Mit Apple anmelden',
                                                  onTap: _busy
                                                      ? null
                                                      : () => _socialSignIn(
                                                          AuthSocialProvider
                                                              .apple)),
                                              const SizedBox(height: 14),
                                              Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text('Noch kein Konto? ',
                                                        style: theme
                                                            .textTheme.bodySmall
                                                            ?.copyWith(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.75))),
                                                    _TextLink(
                                                        label:
                                                            'Jetzt registrieren',
                                                        onTap: () => Navigator
                                                                .of(context)
                                                            .push(MaterialPageRoute(
                                                                builder: (_) =>
                                                                    RegisterScreen(returnTabIndex: widget.returnTabIndex)))),
                                                  ]),
                                              const SizedBox(height: 14),
                                              Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .verified_user_outlined,
                                                        size: 16,
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.65)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Deine Daten werden sicher verschlüsselt übertragen.',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: theme.textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.70),
                                                                height: 1.35),
                                                      ),
                                                    ),
                                                  ]),
                                            ]),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            16, 8, 16, 22 + media.padding.bottom),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: _Pressable(
                              onTap: _continueAsGuest,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.14)),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_outline,
                                          size: 18,
                                          color: Colors.white
                                              .withValues(alpha: 0.90)),
                                      const SizedBox(width: 10),
                                      Text('Ohne Anmeldung weiter',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900)),
                                    ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_checkingSession)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: _GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: BrandColors.logoAccent)),
                          const SizedBox(width: 12),
                          Text('Session prüfen…',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  final bool peekClear;
  const _AuthBackdrop({required this.peekClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final dark = theme.colorScheme.secondary;

    final bands = peekClear
        ? const <_BlurBandSpec>[
            _BlurBandSpec(flex: 22, sigma: 0, tintOpacity: 0.05),
            _BlurBandSpec(flex: 26, sigma: 0, tintOpacity: 0.06),
            _BlurBandSpec(flex: 28, sigma: 0, tintOpacity: 0.07),
            _BlurBandSpec(flex: 24, sigma: 0, tintOpacity: 0.08),
          ]
        : const <_BlurBandSpec>[
            _BlurBandSpec(flex: 22, sigma: 0, tintOpacity: 0.12),
            _BlurBandSpec(flex: 26, sigma: 8, tintOpacity: 0.17),
            _BlurBandSpec(flex: 28, sigma: 14, tintOpacity: 0.22),
            _BlurBandSpec(flex: 24, sigma: 20, tintOpacity: 0.28),
          ];

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/register.png',
            fit: BoxFit.cover, alignment: Alignment.topCenter),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: peekClear ? 0.0 : 2.0, sigmaY: peekClear ? 0.0 : 2.0),
            child: const SizedBox.expand(),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(primary, BrandColors.logoGradientStart, 0.35)!
                    .withValues(alpha: peekClear ? 0.14 : 0.36),
                Color.lerp(dark, BrandColors.logoGradientEnd, 0.55)!
                    .withValues(alpha: peekClear ? 0.12 : 0.28),
              ],
            ),
          ),
        ),
        Column(
          children: [
            for (final band in bands)
              Expanded(
                flex: band.flex,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: band.sigma.toDouble(),
                        sigmaY: band.sigma.toDouble()),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: theme.colorScheme.surface
                              .withValues(alpha: band.tintOpacity)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  theme.colorScheme.surface
                      .withValues(alpha: peekClear ? 0.12 : 0.40),
                  theme.colorScheme.surface
                      .withValues(alpha: peekClear ? 0.18 : 0.62),
                ],
                stops: const [0.55, 0.82, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlurBandSpec {
  final int flex;
  final int sigma;
  final double tintOpacity;
  const _BlurBandSpec(
      {required this.flex, required this.sigma, required this.tintOpacity});
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _GlassSuffixIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassSuffixIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Keep it “free-floating” inside the text field (no chip/background).
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
            child: Icon(icon,
                color: Colors.white.withValues(alpha: 0.85), size: 20)),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // Match the Register form panel glass.
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        // Keep the overall card lightly blurred, like on Register.
        // (Register applies stronger blur per text field.)
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            // Same tint + border as Register.
            color: Colors.black.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SITTextField extends StatelessWidget {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?) validator;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffix;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  const _SITTextField({
    required this.label,
    required this.placeholder,
    required this.controller,
    required this.focusNode,
    this.nextFocusNode,
    required this.keyboardType,
    required this.textInputAction,
    required this.validator,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffix,
    this.autocorrect = false,
    this.enableSuggestions = false,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      textCapitalization: textCapitalization,
      style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
      validator: validator,
      onFieldSubmitted: (v) {
        if (nextFocusNode != null) {
          FocusScope.of(context).requestFocus(nextFocusNode);
        } else {
          onSubmitted?.call(v);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        hintStyle: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.42),
            fontWeight: FontWeight.w600),
        labelStyle: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Icon(prefixIcon,
              color: Colors.white.withValues(alpha: 0.78), size: 18),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix == null
            ? null
            : Padding(padding: const EdgeInsets.only(right: 8), child: suffix),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.12),
        contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.10))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                const BorderSide(color: BrandColors.logoAccent, width: 1.4)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
                color: BrandColors.danger.withValues(alpha: 0.9), width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
                color: BrandColors.danger.withValues(alpha: 0.95), width: 1.3)),
        errorStyle: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            height: 1.25,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  final bool busy;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _PrimaryAuthButton(
      {required this.busy,
      required this.label,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 54,
        decoration: BoxDecoration(
          gradient: onTap == null
              ? LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.08)
                ])
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.85)
                    ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: onTap == null
                  ? Colors.white.withValues(alpha: 0.10)
                  : theme.colorScheme.primary.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
                color:
                    Colors.black.withValues(alpha: onTap == null ? 0.12 : 0.26),
                blurRadius: 24,
                offset: const Offset(0, 16))
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) ...[
              SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white
                          .withValues(alpha: onTap == null ? 0.75 : 1.0))),
              const SizedBox(width: 10),
            ] else ...[
              Icon(icon,
                  color: Colors.white
                      .withValues(alpha: onTap == null ? 0.75 : 1.0),
                  size: 20),
              const SizedBox(width: 10),
            ],
            Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(
          child: Container(
              height: 1,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                Colors.white.withValues(alpha: 0.00),
                Colors.white.withValues(alpha: 0.22)
              ])))),
      const SizedBox(width: 10),
      Text('ODER',
          style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.70), letterSpacing: 0.8)),
      const SizedBox(width: 10),
      Expanded(
          child: Container(
              height: 1,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.00)
              ])))),
    ]);
  }
}

class _TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: BrandColors.logoAccent, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  const _Pressable(
      {required this.child, required this.onTap, required this.borderRadius});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        scale: _down ? 0.985 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: enabled ? 1.0 : 0.55,
          child: widget.child,
        ),
      ),
    );
  }
}

class _PasswordResetSheet extends StatefulWidget {
  final String initialEmail;
  const _PasswordResetSheet({required this.initialEmail});

  @override
  State<_PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<_PasswordResetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Bitte gib eine gültige E-Mail-Adresse ein.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'Bitte gib eine gültige E-Mail-Adresse ein.';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      Navigator.of(context).maybePop();
      await AppPopup.toast(
        context,
        icon: Icons.mark_email_read_outlined,
        title: 'E-Mail gesendet',
        message:
            'Wenn ein Konto existiert, erhältst du gleich einen Link zum Zurücksetzen.',
      );
    } catch (e) {
      debugPrint('[PasswordReset] submit failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          'Gib deine E-Mail ein. Wir senden dir einen sicheren Link, um dein Passwort zurückzusetzen.',
          style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78), height: 1.45),
        ),
        const SizedBox(height: 14),
        _SITResetField(controller: _emailCtrl, validator: _validateEmail),
        const SizedBox(height: 16),
        _PrimarySheetButton(
            busy: _busy,
            label: _busy ? 'Senden…' : 'Link senden',
            onTap: _busy ? null : _submit),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _SITResetField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?) validator;
  const _SITResetField({required this.controller, required this.validator});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface),
      validator: validator,
      decoration: InputDecoration(
        labelText: 'E-Mail',
        hintText: 'deine@email.com',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                const BorderSide(color: BrandColors.logoAccent, width: 1.4)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
                color: BrandColors.danger.withValues(alpha: 0.9), width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
                color: BrandColors.danger.withValues(alpha: 0.95), width: 1.3)),
        errorStyle: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.95), height: 1.25),
      ),
    );
  }
}

class _PrimarySheetButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback? onTap;
  const _PrimarySheetButton(
      {required this.busy, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: onTap == null
              ? LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.10)
                ])
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.85)
                    ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (busy) ...[
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 10),
          ],
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

double mathMax(double a, double b) => a > b ? a : b;
