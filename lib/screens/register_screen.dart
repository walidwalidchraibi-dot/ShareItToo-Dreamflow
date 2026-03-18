import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/developer_preview_service.dart';
import 'package:lendify/navigation/main_navigation.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/services/auth_service.dart';
import 'package:lendify/widgets/app_popup.dart';
import 'package:lendify/screens/login_screen.dart';
import 'package:lendify/widgets/sit_logo_header.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Hot-reload-safe: on Flutter Web, state objects can be rehydrated with
  // previously absent fields, resulting in `null` where a FocusNode/controller
  // is expected. Keep these nullable and lazily initialize on access.
  TextEditingController? _nameCtrl;
  TextEditingController? _emailCtrl;
  TextEditingController? _pwCtrl;
  TextEditingController? _pw2Ctrl;

  FocusNode? _nameFocus;
  FocusNode? _emailFocus;
  FocusNode? _pw1Focus;
  FocusNode? _pw2Focus;

  TextEditingController get _nameController => _nameCtrl ??= TextEditingController();
  TextEditingController get _emailController => _emailCtrl ??= TextEditingController();
  TextEditingController get _pw1Controller => _pwCtrl ??= TextEditingController();
  TextEditingController get _pw2Controller => _pw2Ctrl ??= TextEditingController();

  FocusNode get _nameFocusNode => _nameFocus ??= FocusNode();
  FocusNode get _emailFocusNode => _emailFocus ??= FocusNode();
  FocusNode get _pw1FocusNode => _pw1Focus ??= FocusNode();
  FocusNode get _pw2FocusNode => _pw2Focus ??= FocusNode();

  bool _pwListenersAttached = false;

  void _ensurePasswordListeners() {
    if (_pwListenersAttached) return;
    _pw1Controller.addListener(_recomputePasswordState);
    _pw2Controller.addListener(_recomputePasswordState);
    _pwListenersAttached = true;
  }

  bool _pw1Visible = false;
  bool _pw2Visible = false;
  bool _pwLengthOk = false;
  bool _pwMatchOk = false;

  bool _busy = false;
  bool _pressingCta = false;

  @override
  void dispose() {
    _nameCtrl?.dispose();
    _emailCtrl?.dispose();
    _pwCtrl?.dispose();
    _pw2Ctrl?.dispose();
    _nameFocus?.dispose();
    _emailFocus?.dispose();
    _pw1Focus?.dispose();
    _pw2Focus?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ensurePasswordListeners();
    _recomputePasswordState();
  }

  void _recomputePasswordState() {
    final pw1 = _pw1Controller.text;
    final pw2 = _pw2Controller.text;
    final lengthOk = pw1.length >= 8;
    final matchOk = pw2.isNotEmpty && pw1 == pw2;
    if (lengthOk == _pwLengthOk && matchOk == _pwMatchOk) return;
    setState(() {
      _pwLengthOk = lengthOk;
      _pwMatchOk = matchOk;
    });
  }

  Future<void> _register() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final email = _emailController.text.trim();
      final pw = _pw1Controller.text;
      final pw2 = _pw2Controller.text;
      final okEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
      if (!okEmail) {
        await AppPopup.toast(context, icon: Icons.error_outline, title: 'Bitte gib eine gültige E-Mail-Adresse ein.');
        return;
      }
      if (pw.trim().isEmpty) {
        await AppPopup.toast(context, icon: Icons.error_outline, title: 'Bitte gib dein Passwort ein.');
        return;
      }
      if (pw.length < 8) {
        await AppPopup.toast(context, icon: Icons.error_outline, title: 'Das Passwort ist zu kurz.');
        return;
      }
      if (pw2.isEmpty || pw2 != pw) {
        await AppPopup.toast(context, icon: Icons.error_outline, title: 'Bitte bestätige dein Passwort.');
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
      final result = await AuthService.registerLocalAccount(email: email, password: pw);
      if (!mounted) return;
      if (!result.ok) {
        final msg = switch (result.failure) {
          AuthFailure.emailInUse => 'Diese E-Mail ist bereits registriert.',
          AuthFailure.network => 'Es ist ein Netzwerkfehler aufgetreten. Bitte versuche es erneut.',
          _ => 'Es ist ein Fehler aufgetreten. Bitte versuche es erneut.',
        };
        await AppPopup.toast(context, icon: Icons.error_outline, title: msg);
        return;
      }

      await context.read<DeveloperPreviewController>().setState(DeveloperUserState.loggedIn);
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainNavigation()), (route) => false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hot-reload safety: if controllers were re-created after state
    // rehydration, ensure listeners exist.
    _ensurePasswordListeners();
    final theme = Theme.of(context);
    const onImageText = Colors.white;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _CenteredTitleAppBar(
        title: 'Registrierung',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: Stack(children: [
        const Positioned.fill(
          child: IgnorePointer(
            // Safety: BackdropFilter/DecoratedBox layers can sometimes win hit-testing
            // on certain platforms/compositing paths. The backdrop must never block
            // interactions with the form.
            child: _RegisterBackdrop(),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final topInset = MediaQuery.paddingOf(context).top;
                // Move the whole content further up (~1.5cm) compared to the
                // previous layout.
                final extraTopBase = (constraints.maxHeight * 0.12).clamp(90.0, 160.0);
                // Fine-tuning offsets (approx.): 1cm ~= 36px.
                // User request:
                //  - Move everything ~1cm further up
                //  - Move the CTA button + everything below it ~3cm further down
                const cmPx = 36.0;
                // Additional request: move the whole page content (below the header/title)
                // ~1.5cm further up.
                const shiftUpExtraPx = cmPx * 1.5; // ~54px
                final extraTop = (extraTopBase - 90.0 - 54.0 - cmPx - shiftUpExtraPx).clamp(0.0, 140.0);
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topInset + kToolbarHeight + 12 + extraTop,
                    16,
                    // Ensure content below the CTA (trust text, login row, demo hint)
                    // is never clipped by the system bottom inset (home indicator)
                    // or the keyboard.
                    32 + MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - (topInset + kToolbarHeight + 12 + extraTop)),
                    child: IntrinsicHeight(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const SitLogoHeader(showSlogan: false),
                        const SizedBox(height: 18),
                        Text(
                          'In 60 Sekunden starten',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(color: onImageText, fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Mieten & vermieten – sicher, einfach und in deiner Nähe.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: onImageText.withValues(alpha: 0.86), height: 1.35, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 26),
                        _FormFocusPanel(
                          child: _RegisterFormCard(
                            nameCtrl: _nameController,
                            emailCtrl: _emailController,
                            pw1Ctrl: _pw1Controller,
                            pw2Ctrl: _pw2Controller,
                            nameFocus: _nameFocusNode,
                            emailFocus: _emailFocusNode,
                            pw1Focus: _pw1FocusNode,
                            pw2Focus: _pw2FocusNode,
                            pw1Visible: _pw1Visible,
                            pw2Visible: _pw2Visible,
                            pwLengthOk: _pwLengthOk,
                            pwMatchOk: _pwMatchOk,
                            onTogglePw1: () => setState(() => _pw1Visible = !_pw1Visible),
                            onTogglePw2: () => setState(() => _pw2Visible = !_pw2Visible),
                          ),
                        ),
                        const SizedBox(height: 18 + (cmPx * 3)),
                        _PrimaryCtaButton(
                          icon: Icons.person_add_alt_1,
                          label: _busy ? 'Bitte warten…' : 'Konto erstellen',
                          enabled: !_busy,
                          pressing: _pressingCta,
                          onPressingChanged: (v) => setState(() => _pressingCta = v),
                          onTap: _busy ? null : _register,
                        ),
                        const SizedBox(height: 14),
                        const _TrustSection(),
                        const Spacer(),
                        const SizedBox(height: 18),
                        _SecondaryActionRow(
                          onLoginTap: () {
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Demo‑Modus – keine echte Registrierung',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(color: onImageText.withValues(alpha: 0.65), fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _RegisterFormCard extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController pw1Ctrl;
  final TextEditingController pw2Ctrl;
  final FocusNode nameFocus;
  final FocusNode emailFocus;
  final FocusNode pw1Focus;
  final FocusNode pw2Focus;
  final bool pw1Visible;
  final bool pw2Visible;
  final bool pwLengthOk;
  final bool pwMatchOk;
  final VoidCallback onTogglePw1;
  final VoidCallback onTogglePw2;
  const _RegisterFormCard({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.pw1Ctrl,
    required this.pw2Ctrl,
    required this.nameFocus,
    required this.emailFocus,
    required this.pw1Focus,
    required this.pw2Focus,
    required this.pw1Visible,
    required this.pw2Visible,
    required this.pwLengthOk,
    required this.pwMatchOk,
    required this.onTogglePw1,
    required this.onTogglePw2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _GlassTextField(
        label: 'Name',
        controller: nameCtrl,
        focusNode: nameFocus,
        nextFocus: emailFocus,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.name,
        autofillHints: const [AutofillHints.name],
        prefixIcon: Icons.person_outline,
      ),
      const SizedBox(height: 12),
      _GlassTextField(
        label: 'E‑Mail',
        controller: emailCtrl,
        focusNode: emailFocus,
        nextFocus: pw1Focus,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        prefixIcon: Icons.mail_outline,
      ),
      const SizedBox(height: 12),
      _GlassTextField(
        label: 'Passwort',
        controller: pw1Ctrl,
        focusNode: pw1Focus,
        nextFocus: pw2Focus,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.visiblePassword,
        autofillHints: const [AutofillHints.newPassword],
        prefixIcon: Icons.lock_outline,
        obscureText: !pw1Visible,
        onToggleObscure: onTogglePw1,
        toggleObscureIcon: pw1Visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        assistiveBelow: _PasswordHintRow(text: 'Mind. 8 Zeichen', ok: pwLengthOk, showState: pw1Ctrl.text.isNotEmpty),
      ),
      const SizedBox(height: 10),
      _GlassTextField(
        label: 'Passwort wiederholen',
        controller: pw2Ctrl,
        focusNode: pw2Focus,
        textInputAction: TextInputAction.done,
        keyboardType: TextInputType.visiblePassword,
        autofillHints: const [AutofillHints.newPassword],
        prefixIcon: Icons.lock_outline,
        obscureText: !pw2Visible,
        onToggleObscure: onTogglePw2,
        toggleObscureIcon: pw2Visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        assistiveBelow: _PasswordHintRow(text: 'Passwörter müssen übereinstimmen', ok: pwMatchOk, showState: pw2Ctrl.text.isNotEmpty, warnWhenNotOk: true),
        suffixStatus: pw2Ctrl.text.isEmpty ? null : (pwMatchOk ? _FieldStatus.ok : _FieldStatus.warn),
      ),
    ]);
  }
}

class _TrustSection extends StatelessWidget {
  const _TrustSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onImageText = Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text('Sicher. Transparent. Fair.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: onImageText, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Verifizierte Profile & sichere Übergaben', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: onImageText.withValues(alpha: 0.86), height: 1.25, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FormFocusPanel extends StatelessWidget {
  final Widget child;
  const _FormFocusPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        // Keep focus on the text fields: the big panel is only lightly blurred.
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: child,
        ),
      ),
    );
  }
}

class _RegisterBackdrop extends StatelessWidget {
  const _RegisterBackdrop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final dark = theme.colorScheme.secondary;

    // We keep this in 4 bands (top→bottom) to approximate a vertical blur ramp
    // without expensive per-pixel blur shaders.
    const bands = <_BlurBandSpec>[
      _BlurBandSpec(flex: 22, sigma: 0, tintOpacity: 0.12),
      _BlurBandSpec(flex: 26, sigma: 8, tintOpacity: 0.17),
      _BlurBandSpec(flex: 28, sigma: 14, tintOpacity: 0.22),
      _BlurBandSpec(flex: 24, sigma: 20, tintOpacity: 0.28),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/register.png', fit: BoxFit.cover, alignment: Alignment.topCenter),

        // Subtle overall blur to make the photo feel more premium (kept small for performance).
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
            child: const SizedBox.expand(),
          ),
        ),

        // Soft brand tint to match SIT look and keep text readable.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(primary, BrandColors.logoGradientStart, 0.35)!.withValues(alpha: 0.36),
                Color.lerp(dark, BrandColors.logoGradientEnd, 0.55)!.withValues(alpha: 0.28),
              ],
            ),
          ),
        ),

        // Blur + fade increasing towards the bottom.
        Column(
          children: [
            for (final band in bands)
              Expanded(
                flex: band.flex,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: band.sigma.toDouble(), sigmaY: band.sigma.toDouble()),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: theme.colorScheme.surface.withValues(alpha: band.tintOpacity)),
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Extra bottom fade so the CTA area stays premium/clean.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  theme.colorScheme.surface.withValues(alpha: 0.40),
                  theme.colorScheme.surface.withValues(alpha: 0.62),
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
  const _BlurBandSpec({required this.flex, required this.sigma, required this.tintOpacity});
}

class _CenteredTitleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onBack;
  const _CenteredTitleAppBar({required this.title, required this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onImageText = Colors.white;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: onImageText.withValues(alpha: 0.92)),
              tooltip: 'Zurück',
            ),
          ),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(color: onImageText, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

enum _FieldStatus { ok, warn }

class _GlassTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  /// If null (can happen on Flutter Web after hot reload / state rehydration),
  /// the widget will create and manage its own FocusNode to avoid runtime
  /// crashes like: "type 'Null' is not a subtype of type 'FocusNode'".
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final TextInputAction textInputAction;
  final TextInputType keyboardType;
  final List<String>? autofillHints;
  final IconData prefixIcon;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final IconData? toggleObscureIcon;
  final Widget? assistiveBelow;
  final _FieldStatus? suffixStatus;
  const _GlassTextField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.textInputAction,
    required this.keyboardType,
    required this.prefixIcon,
    this.nextFocus,
    this.autofillHints,
    this.obscureText = false,
    this.onToggleObscure,
    this.toggleObscureIcon,
    this.assistiveBelow,
    this.suffixStatus,
  });

  @override
  State<_GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<_GlassTextField> {
  bool _focused = false;
  late FocusNode _effectiveFocusNode;
  bool _ownsFocusNode = false;

  FocusNode _resolveFocusNode(FocusNode? provided) {
    if (provided != null) return provided;
    _ownsFocusNode = true;
    return FocusNode();
  }

  void _attach(FocusNode node) {
    _effectiveFocusNode = node;
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  void _detachAndMaybeDispose() {
    _effectiveFocusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) {
      _effectiveFocusNode.dispose();
    }
    _ownsFocusNode = false;
  }

  @override
  void initState() {
    super.initState();
    _attach(_resolveFocusNode(widget.focusNode));
  }

  @override
  void didUpdateWidget(covariant _GlassTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextNode = widget.focusNode;
    final oldNode = oldWidget.focusNode;
    if (!identical(nextNode, oldNode)) {
      _detachAndMaybeDispose();
      _attach(_resolveFocusNode(nextNode));
    }
  }

  @override
  void dispose() {
    _detachAndMaybeDispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _focused = _effectiveFocusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    const onImageText = Colors.white;

    // Stronger blur where the user interacts to reduce background distraction.
    final double fieldSigma = _focused ? 16.0 : 10.0;

    Color borderColor() {
      if (!_focused) return Colors.white.withValues(alpha: 0.30);
      return Color.lerp(primary, Colors.white, 0.25)!.withValues(alpha: 0.92);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          // Blur only where the user types (not the whole form card).
          filter: ImageFilter.blur(sigmaX: fieldSigma, sigmaY: fieldSigma),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: _focused ? 0.14 : 0.11),
                  Colors.white.withValues(alpha: _focused ? 0.07 : 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor(), width: _focused ? 1.35 : 1.15),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: _focused ? 0.24 : 0.18), blurRadius: _focused ? 20 : 14, offset: const Offset(0, 10)),
                if (_focused) BoxShadow(color: primary.withValues(alpha: 0.18), blurRadius: 26, offset: const Offset(0, 12)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: widget.controller,
              focusNode: _effectiveFocusNode,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              obscureText: widget.obscureText,
              enableSuggestions: !widget.obscureText,
              autocorrect: !widget.obscureText,
              style: theme.textTheme.bodyMedium?.copyWith(color: onImageText, fontSize: 14, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: widget.label,
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                labelStyle: theme.textTheme.bodySmall?.copyWith(color: onImageText.withValues(alpha: 0.84), fontWeight: FontWeight.w800),
                border: InputBorder.none,
                prefixIcon: Icon(widget.prefixIcon, color: onImageText.withValues(alpha: 0.92), size: 20),
                prefixIconConstraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                suffixIcon: _suffix(context),
                contentPadding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
              ),
              onSubmitted: (_) {
                if (widget.textInputAction == TextInputAction.done) {
                  FocusScope.of(context).unfocus();
                } else if (widget.nextFocus != null) {
                  widget.nextFocus!.requestFocus();
                }
              },
            ),
          ),
        ),
      ),
      if (widget.assistiveBelow != null) ...[
        const SizedBox(height: 8),
        widget.assistiveBelow!,
      ],
    ]);
  }

  Widget? _suffix(BuildContext context) {
    const iconColor = Colors.white;

    Widget? statusIcon;
    if (widget.suffixStatus != null) {
      statusIcon = switch (widget.suffixStatus!) {
        _FieldStatus.ok => Icon(Icons.check_circle_rounded, color: BrandColors.success.withValues(alpha: 0.95), size: 18),
        _FieldStatus.warn => Icon(Icons.error_outline_rounded, color: BrandColors.danger.withValues(alpha: 0.92), size: 18),
      };
    }

    final toggle = (widget.onToggleObscure != null && widget.toggleObscureIcon != null)
        ? IconButton(
            onPressed: widget.onToggleObscure,
            icon: Icon(widget.toggleObscureIcon, size: 18, color: iconColor.withValues(alpha: 0.82)),
            tooltip: widget.obscureText ? 'Passwort anzeigen' : 'Passwort verbergen',
          )
        : null;

    if (toggle == null && statusIcon == null) return null;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (statusIcon != null) ...[statusIcon, const SizedBox(width: 6)],
      if (toggle != null) toggle,
    ]);
  }
}

class _PasswordHintRow extends StatelessWidget {
  final String text;
  final bool ok;
  final bool showState;
  final bool warnWhenNotOk;
  const _PasswordHintRow({required this.text, required this.ok, required this.showState, this.warnWhenNotOk = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onImageText = Colors.white;
    final showIcon = showState;
    final Color color;
    if (!showState) {
      color = onImageText.withValues(alpha: 0.62);
    } else if (ok) {
      color = BrandColors.success.withValues(alpha: 0.95);
    } else if (warnWhenNotOk) {
      color = BrandColors.danger.withValues(alpha: 0.92);
    } else {
      color = onImageText.withValues(alpha: 0.62);
    }

    return Row(children: [
      AnimatedOpacity(
        opacity: showIcon ? 1 : 0,
        duration: const Duration(milliseconds: 140),
        child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 16, color: ok ? BrandColors.success.withValues(alpha: 0.95) : BrandColors.danger.withValues(alpha: 0.92)),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _PrimaryCtaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool pressing;
  final ValueChanged<bool> onPressingChanged;
  final VoidCallback? onTap;
  const _PrimaryCtaButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.pressing,
    required this.onPressingChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // SIT Blue CTA (high-conversion, consistent with primary brand color)
    final primary = theme.colorScheme.primary;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(primary, Colors.black, 0.10)!,
        Color.lerp(primary, Colors.white, 0.18)!,
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => onPressingChanged(true) : null,
      onTapCancel: enabled ? () => onPressingChanged(false) : null,
      onTapUp: enabled ? (_) => onPressingChanged(false) : null,
      onTap: enabled ? onTap : null,
      child: AnimatedScale(
        scale: pressing ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: enabled ? gradient : null,
            color: enabled ? null : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.26), blurRadius: 22, offset: const Offset(0, 12)),
                    BoxShadow(color: primary.withValues(alpha: 0.18), blurRadius: 26, offset: const Offset(0, 14)),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [
            Icon(icon, color: Colors.white.withValues(alpha: enabled ? 0.98 : 0.70), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: enabled ? 0.98 : 0.70)),
              ),
            ),
            const SizedBox(width: 30),
          ]),
        ),
      ),
    );
  }
}

class _SecondaryActionRow extends StatelessWidget {
  final VoidCallback onLoginTap;
  const _SecondaryActionRow({required this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onImageText = Colors.white;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Schon ein Konto? ', style: theme.textTheme.bodySmall?.copyWith(color: onImageText.withValues(alpha: 0.78), height: 1.2, fontWeight: FontWeight.w700)),
        GestureDetector(
          onTap: onLoginTap,
          child: Text(
            'Anmelden',
            style: theme.textTheme.bodySmall?.copyWith(color: onImageText, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: onImageText),
          ),
        ),
      ],
    );
  }
}
