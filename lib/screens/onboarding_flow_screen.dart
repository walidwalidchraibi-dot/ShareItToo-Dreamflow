import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/screens/login_screen.dart';
import 'package:lendify/screens/register_screen.dart';
import 'package:lendify/screens/developer_preview_screen.dart';
import 'package:lendify/navigation/main_navigation.dart';
import 'package:lendify/navigation/main_nav_controller.dart';
import 'package:lendify/services/developer_preview_service.dart';
import 'package:lendify/widgets/sit_logo_header.dart';
import 'package:provider/provider.dart';

class FirstLaunchFlowScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const FirstLaunchFlowScreen({super.key, required this.onFinished});

  @override
  State<FirstLaunchFlowScreen> createState() => _FirstLaunchFlowScreenState();
}

class _FirstLaunchFlowScreenState extends State<FirstLaunchFlowScreen> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.delayed(const Duration(milliseconds: 1100)).then((_) {
      if (!mounted) return;
      setState(() => _showSplash = false);
    }));
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const _SplashScreen();
    return const LoggedOutLandingScreen();
  }
}

class LoggedOutLandingScreen extends StatefulWidget {
  const LoggedOutLandingScreen({super.key});

  @override
  State<LoggedOutLandingScreen> createState() => _LoggedOutLandingScreenState();
}

class _LoggedOutLandingScreenState extends State<LoggedOutLandingScreen> {
  int _tapCount = 0;
  Timer? _resetTimer;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _slideImages = <String>[
    'assets/images/Onboarding_seite_1.png',
    'assets/images/seite_2.png',
    'assets/images/seite_3.png',
  ];

  static const _slideTitles = <String>[
    'Teile Dinge in deiner Nähe',
    'Verdiene Geld mit Dingen, die du besitzt',
    'Sicher. Transparent. Fair.',
  ];

  static const _slideDescriptions = <String>[
    'Miete Werkzeuge, Technik, Outdoor-Gear und vieles mehr – direkt von Menschen aus deiner Stadt.',
    'Vermiete Werkzeuge, Technik, Outdoor-Gear, Küchenmaschinen, Fahrräder, Schmuck und vieles mehr.',
    'Verifizierte Profile, Bewertungen, ein integrierter Chat sowie eine bilddokumentierte Übergabe und Rückgabe geben dir Sicherheit.',
  ];

  void _handleSecretTap() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _tapCount = 0);
    });
    setState(() => _tapCount += 1);
    if (_tapCount >= 7) {
      _resetTimer?.cancel();
      _tapCount = 0;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeveloperPreviewScreen()));
    }
  }

  void _goNext() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _continueWithoutAccount() {
    try {
      context.read<DeveloperPreviewController>().setState(DeveloperUserState.loggedOut);
    } catch (_) {}
    try {
      context.read<MainNavController>().setIndex(0);
    } catch (_) {}
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ══════════════════════════════════════════════════════════════════
          // BACKGROUND: Fullscreen image
          // ══════════════════════════════════════════════════════════════════
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: ColorFiltered(
                key: ValueKey(_currentPage),
                // Seite 3 (index 2) etwas heller machen
                colorFilter: _currentPage == 2
                    ? const ColorFilter.matrix(<double>[
                        1.15, 0, 0, 0, 15,  // Red
                        0, 1.15, 0, 0, 15,  // Green
                        0, 0, 1.15, 0, 15,  // Blue
                        0, 0, 0, 1, 0,       // Alpha
                      ])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: Transform.scale(
                  // Seite 2 (index 1) leicht zoomen damit alle 3 Personen groß erscheinen
                  scale: _currentPage == 1 ? 1.15 : 1.0,
                  alignment: Alignment.center,
                  child: Image.asset(
                    _slideImages[_currentPage],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    // Seite 2: 2cm nach rechts + nach oben; Seite 3: nach oben
                    alignment: _currentPage == 1 
                        ? const Alignment(0.40, -0.30)  // Bild 2: nach rechts + hoch
                        : (_currentPage == 2 
                            ? const Alignment(0, -0.30)   // Bild 3: nach oben
                            : Alignment.center),           // Bild 1: zentriert
                  ),
                ),
              ),
            ),
          ),
          // Readability gradient overlay (nur oben, unten NICHT dunkel)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.30, 0.55],
                  ),
                ),
              ),
            ),
          ),
          // ══════════════════════════════════════════════════════════════════
          // FOREGROUND: Logo, PageView, Buttons
          // ══════════════════════════════════════════════════════════════════
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ═══════════════════════════════════════════════════════════
                // TOP: Logo Header (like Login screen)
                // ═══════════════════════════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleSecretTap,
                    child: const SitLogoHeader(showSlogan: true),
                  ),
                ),
                // ═══════════════════════════════════════════════════════════
                // MIDDLE: PageView with text content
                // ═══════════════════════════════════════════════════════════
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const PageScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Schrift weiter oben, nicht die Personen überlappen
                            const SizedBox(height: 24),
                            Text(
                              _slideTitles[index],
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 8)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _slideDescriptions[index],
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 6)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // ═══════════════════════════════════════════════════════════
                // BOTTOM: Glass Card with Dots + Buttons (like Login screen)
                // ═══════════════════════════════════════════════════════════
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
                  child: _OnboardingGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Page indicator dots
                          _DotsIndicator(currentIndex: _currentPage, count: 3),
                          const SizedBox(height: 14),
                          // Buttons depend on current page
                          if (_currentPage < 2) ...[
                            // Page 1 & 2: Weiter + Zurück buttons
                            Row(
                              children: [
                                // Zurück button (disabled on page 0)
                                Expanded(
                                  child: _OnboardingSecondaryButton(
                                    label: 'Zurück',
                                    icon: Icons.arrow_back,
                                    onTap: _currentPage > 0 ? _goBack : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Weiter button
                                Expanded(
                                  child: _OnboardingPrimaryButton(
                                    label: 'Weiter',
                                    icon: Icons.arrow_forward,
                                    iconTrailing: true,
                                    onTap: _goNext,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Skip link
                            _OnboardingTextLink(
                              label: 'Weiter ohne Konto →',
                              onTap: _continueWithoutAccount,
                            ),
                          ] else ...[
                            // Page 3: Anmelden + Konto erstellen buttons
                            _OnboardingPrimaryButton(
                              label: 'Anmelden',
                              icon: Icons.login,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _OnboardingSecondaryButton(
                              label: 'Konto erstellen',
                              icon: Icons.person_add_alt_1,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Back + Continue without account links
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _OnboardingTextLink(
                                  label: '← Zurück',
                                  onTap: _goBack,
                                ),
                                const SizedBox(width: 20),
                                _OnboardingTextLink(
                                  label: 'Weiter ohne Konto →',
                                  onTap: _continueWithoutAccount,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// GLASS CARD (like Login screen)
// ════════════════════════════════════════════════════════════════════════════

class _OnboardingGlassCard extends StatelessWidget {
  final Widget child;
  const _OnboardingGlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          decoration: BoxDecoration(
            // Nur ganz leicht getönt, weniger Blur
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PRIMARY BUTTON (like Login screen _PrimaryAuthButton)
// ════════════════════════════════════════════════════════════════════════════

class _OnboardingPrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool iconTrailing;
  const _OnboardingPrimaryButton({required this.label, required this.icon, this.onTap, this.iconTrailing = false});

  @override
  State<_OnboardingPrimaryButton> createState() => _OnboardingPrimaryButtonState();
}

class _OnboardingPrimaryButtonState extends State<_OnboardingPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: enabled ? 1.0 : 0.5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                height: 40, // 1/2 kleiner (war 54)
                decoration: BoxDecoration(
                  // Nur leicht blurred, nicht dunkel, nicht blau
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.iconTrailing
                      ? [
                          Text(widget.label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(width: 8),
                          Icon(widget.icon, color: Colors.white, size: 17),
                        ]
                      : [
                          Icon(widget.icon, color: Colors.white, size: 17),
                          const SizedBox(width: 8),
                          Text(widget.label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SECONDARY BUTTON (like Login screen style)
// ════════════════════════════════════════════════════════════════════════════

class _OnboardingSecondaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _OnboardingSecondaryButton({required this.label, required this.icon, this.onTap});

  @override
  State<_OnboardingSecondaryButton> createState() => _OnboardingSecondaryButtonState();
}

class _OnboardingSecondaryButtonState extends State<_OnboardingSecondaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: enabled ? 1.0 : 0.5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                height: 40, // 1/2 kleiner (war 54)
                decoration: BoxDecoration(
                  // Nur leicht blurred, nicht dunkel
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.7), size: 17),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TEXT LINK (like Login screen _TextLink)
// ════════════════════════════════════════════════════════════════════════════

class _OnboardingTextLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OnboardingTextLink({required this.label, required this.onTap});

  @override
  State<_OnboardingTextLink> createState() => _OnboardingTextLinkState();
}

class _OnboardingTextLinkState extends State<_OnboardingTextLink> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _pressed ? 0.7 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(
            widget.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: BrandColors.logoAccent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DOTS INDICATOR
// ════════════════════════════════════════════════════════════════════════════

class _DotsIndicator extends StatelessWidget {
  final int currentIndex;
  final int count;
  const _DotsIndicator({required this.currentIndex, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
          width: isActive ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SPLASH SCREEN
// ════════════════════════════════════════════════════════════════════════════

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  late final Animation<double> _turns = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0.84, end: 1.08).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 1),
    TweenSequenceItem(tween: Tween<double>(begin: 1.08, end: 0.84).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 1),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = 92.0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Semantics(
          label: 'ShareItToo lädt',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Transform.scale(
                    scale: _scale.value,
                    child: RotationTransition(
                      turns: _turns,
                      child: Image.asset(
                        'assets/images/icononly_transparent_nobuffer.png',
                        width: size,
                        height: size,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            gradient: appBackgroundGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                          ),
                          child: const Icon(Icons.all_inclusive, color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Text('ShareItToo', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
              const SizedBox(height: 6),
              Text(
                'SICHER. LOKAL. FLEXIBEL.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w900, letterSpacing: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ONBOARDING FLOW SCREEN (kept for backwards compatibility)
// ════════════════════════════════════════════════════════════════════════════

class OnboardingFlowScreen extends StatelessWidget {
  final VoidCallback? onDone;
  final bool? showTopBar;
  final bool? showBottomActions;
  final bool? showPageIndicator;
  final bool? wrapScaffold;
  final PageController? pageController;
  final ValueChanged<int>? onPageChanged;
  final bool? renderBackgrounds;
  
  const OnboardingFlowScreen({
    super.key, 
    this.onDone, 
    this.showTopBar = true, 
    this.showBottomActions = true, 
    this.showPageIndicator = true, 
    this.wrapScaffold = true, 
    this.pageController, 
    this.onPageChanged, 
    this.renderBackgrounds = true,
  });

  @override
  Widget build(BuildContext context) {
    // Redirect to the new LoggedOutLandingScreen
    return const LoggedOutLandingScreen();
  }
}
