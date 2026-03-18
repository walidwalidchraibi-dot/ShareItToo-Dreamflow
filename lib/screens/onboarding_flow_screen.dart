import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lendify/theme.dart';
import 'package:lendify/screens/login_screen.dart';
import 'package:lendify/screens/register_screen.dart';
import 'package:lendify/screens/developer_preview_screen.dart';
import 'package:lendify/navigation/main_navigation.dart';
import 'package:lendify/navigation/main_nav_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return OnboardingFlowScreen(onDone: widget.onFinished);
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

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleSecretTap,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ShareItToo', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('Miete alles. Von Leuten in deiner Nähe.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, height: 1.2)),
                  ]),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Row(children: [
                  const Icon(Icons.visibility_outlined, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Guest Preview', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Expanded(child: OnboardingFlowScreen(showTopBar: false, showBottomActions: false, wrapScaffold: false)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(children: [
              _PrimaryCta(
                icon: Icons.login,
                label: 'Anmelden',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
              ),
              const SizedBox(height: 10),
              _SecondaryCta(
                icon: Icons.person_add_alt_1,
                label: 'Konto erstellen',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainNavigation())),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Weiter ohne Konto →'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class OnboardingFlowScreen extends StatefulWidget {
  final VoidCallback? onDone;
  // These are nullable on purpose to make hot-reload/hot-restart transitions
  // resilient in Flutter Web when a previously-constructed widget instance
  // might still carry `null` for newly added fields.
  final bool? showTopBar;
  final bool? showBottomActions;
  final bool? showPageIndicator;
  final bool? wrapScaffold;
  const OnboardingFlowScreen({super.key, this.onDone, this.showTopBar = true, this.showBottomActions = true, this.showPageIndicator = true, this.wrapScaffold = true});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  // NOTE (Flutter Web hot reload): when new fields are added to an existing
  // State class, the already-mounted JS object can carry `undefined` for those
  // fields after hot reload. Accessing e.g. a Map via `[]` then throws
  // `TypeError: Cannot read properties of undefined (reading 'Symbol(dartx._get)')`.
  // Therefore we keep these fields nullable and lazily initialize them.
  PageController? _controller;
  int? _page;

  // Per-slide image placement (persisted locally so you can fine-tune once).
  Map<int, double>? _imageOffsetXBySlide;
  Map<int, double>? _imageOffsetYBySlide;
  Map<int, double>? _imageScaleBySlide;
  Map<int, double>? _legacyAlignXBySlide;
  Map<int, double>? _legacyAlignYBySlide;
  bool? _placementMode;
  Timer? _persistDebounce;

  PageController get _pageController => _controller ??= PageController();
  int get _currentPage => _page ??= 0;
  Map<int, double> get _imageOffsetXMap => _imageOffsetXBySlide ??= <int, double>{};
  Map<int, double> get _imageOffsetYMap => _imageOffsetYBySlide ??= <int, double>{};
  Map<int, double> get _imageScaleMap => _imageScaleBySlide ??= <int, double>{};
  Map<int, double> get _legacyAlignXMap => _legacyAlignXBySlide ??= <int, double>{};
  Map<int, double> get _legacyAlignYMap => _legacyAlignYBySlide ??= <int, double>{};
  bool get _isPlacementMode => _placementMode ??= false;

  bool get _hasAnyBackgroundImages => _slides.any((s) => (s.imagePath ?? '').trim().isNotEmpty);

  bool get _showTopBar => widget.showTopBar ?? true;
  bool get _showBottomActions => widget.showBottomActions ?? true;
  bool get _showPageIndicator => widget.showPageIndicator ?? true;
  bool get _wrapScaffold => widget.wrapScaffold ?? true;

  void _exitToExplore() {
    try {
      context.read<MainNavController>().setIndex(0);
    } catch (_) {
      // Provider may not be available in some preview contexts.
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  static const _slides = <_OnboardingSlideData>[
    _OnboardingSlideData(
      // Backgrounds are now unified: we use the standard SIT blurred blue backdrop
      // instead of per-slide images.
      imagePath: null,
      title: 'Teile Dinge in deiner Nähe',
      body: 'Miete Werkzeuge, Technik, Outdoor-Gear und vieles mehr – direkt von Menschen aus deiner Stadt.',
      bodyMaxLines: 2,
      titleAlign: TextAlign.center,
      imageAlignment: Alignment(0, 0.85),
    ),
    _OnboardingSlideData(
      imagePath: null,
      title: 'Verdiene Geld mit Dingen, die du besitzt',
      body: 'Vermiete Werkzeuge, Technik, Outdoor-Gear, Küchenmaschinen, Fahrräder, Schmuck und vieles mehr – oder miete genau das, was dir gerade fehlt.',
      bodyMaxLines: 3,
      titleAlign: TextAlign.start,
      // Focus more on the top of the image so faces/heads are visible.
      imageAlignment: Alignment(0, -0.72),
    ),
    _OnboardingSlideData(
      imagePath: null,
      title: 'Sicher. Transparent. Fair.',
      body: 'Verifizierte Profile, Bewertungen, ein integrierter Chat sowie eine bilddokumentierte Übergabe und Rückgabe geben dir Sicherheit – beim Mieten und Vermieten.',
      bodyMaxLines: 3,
      titleAlign: TextAlign.center,
    ),
  ];

  /// Increase this when you replace onboarding background assets.
  /// It resets persisted image placement so new assets start fully visible.
  static const int _backgroundAssetsVersion = 4;

  static const String _prefsKeyPrefixX = 'onboarding_image_align_x_';
  static const String _prefsKeyPrefixY = 'onboarding_image_align_y_';
  static const String _prefsKeyPrefixScale = 'onboarding_image_scale_';

  // New (pixel-precise) placement keys. We keep the old alignment keys for
  // backwards compatibility and as a best-effort migration fallback.
  static const String _prefsKeyPrefixOffsetX = 'onboarding_image_offset_x_';
  static const String _prefsKeyPrefixOffsetY = 'onboarding_image_offset_y_';

  @override
  void initState() {
    super.initState();
    // Ensure lazy fields are initialized for the first build (and also makes
    // hot-reload on Flutter Web resilient).
    _pageController;
    _currentPage;
    _imageOffsetXMap;
    _imageOffsetYMap;
    _imageScaleMap;
    _legacyAlignXMap;
    _legacyAlignYMap;
    _isPlacementMode;
    // Only load/persist placement info if onboarding backgrounds are used.
    if (_hasAnyBackgroundImages) unawaited(_loadImagePlacements());
  }

  Future<void> _loadImagePlacements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

       final storedVersion = prefs.getInt('onboarding_bg_version') ?? 0;
       if (storedVersion != _backgroundAssetsVersion) {
         for (var i = 0; i < _slides.length; i++) {
           await prefs.remove('$_prefsKeyPrefixOffsetX$i');
           await prefs.remove('$_prefsKeyPrefixOffsetY$i');
           await prefs.remove('$_prefsKeyPrefixScale$i');
           await prefs.remove('$_prefsKeyPrefixX$i');
           await prefs.remove('$_prefsKeyPrefixY$i');
         }
         await prefs.setInt('onboarding_bg_version', _backgroundAssetsVersion);
       }

      setState(() {
        for (var i = 0; i < _slides.length; i++) {
          final keyX = '$_prefsKeyPrefixOffsetX$i';
          final keyY = '$_prefsKeyPrefixOffsetY$i';
          final keyScale = '$_prefsKeyPrefixScale$i';
          final storedX = prefs.getDouble(keyX);
          final storedY = prefs.getDouble(keyY);
          final storedScale = prefs.getDouble(keyScale);

          // Legacy alignment keys (older builds).
          final legacyAlignX = prefs.getDouble('$_prefsKeyPrefixX$i');
          final legacyAlignY = prefs.getDouble('$_prefsKeyPrefixY$i');

          // Migration (best effort): if the new pixel offsets are not present,
          // fall back to the previous alignment-based values and convert them
          // into a reasonable pixel offset later during layout.
          _imageOffsetXMap[i] = storedX ?? double.nan;
          _imageOffsetYMap[i] = storedY ?? double.nan;
          if (legacyAlignX != null) _legacyAlignXMap[i] = legacyAlignX;
          if (legacyAlignY != null) _legacyAlignYMap[i] = legacyAlignY;
          _imageScaleMap[i] = storedScale ?? 1.0;
        }
      });
    } catch (e) {
      debugPrint('[Onboarding] Failed to load image placements: $e');
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _slides.length; i++) {
          _imageOffsetXMap[i] = 0.0;
          _imageOffsetYMap[i] = 0.0;
          _imageScaleMap[i] = 1.0;
        }
      });
    }
  }

  void _schedulePersistPlacement(int slideIndex, Offset offset, double scale) {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('$_prefsKeyPrefixOffsetX$slideIndex', offset.dx);
        await prefs.setDouble('$_prefsKeyPrefixOffsetY$slideIndex', offset.dy);
        await prefs.setDouble('$_prefsKeyPrefixScale$slideIndex', scale);
      } catch (e) {
        debugPrint('[Onboarding] Failed to persist image placement: $e');
      }
    });
  }

  void _togglePlacementMode() => setState(() => _placementMode = !_isPlacementMode);

  void _resetPlacementForSlide(int slideIndex) {
    setState(() {
      _imageOffsetXMap[slideIndex] = 0.0;
      _imageOffsetYMap[slideIndex] = 0.0;
      _imageScaleMap[slideIndex] = 1.0;
    });
    _schedulePersistPlacement(slideIndex, Offset.zero, 1.0);
  }

  void _nudgeScaleForSlide(int slideIndex, double delta) {
    final currentScale = (_imageScaleMap[slideIndex] ?? 1.0);
    final nextScale = (currentScale + delta).clamp(0.25, 3.50);
    final offset = Offset(
      _imageOffsetXMap[slideIndex] ?? 0.0,
      _imageOffsetYMap[slideIndex] ?? 0.0,
    );
    setState(() => _imageScaleMap[slideIndex] = nextScale);
    _schedulePersistPlacement(slideIndex, offset, nextScale);
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage >= 2) {
      widget.onDone?.call();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_currentPage <= 0) return;
    _pageController.previousPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _skip() {
    // Skip should take the user straight to the auth step (Login/Registration)
    // while keeping the onboarding structure consistent.
    if (_currentPage < 2) {
      _pageController.animateToPage(2, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      return;
    }
    _goRegister();
  }

  void _goRegister() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  void _goLogin() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // When there are no background images, placement mode is meaningless.
    if (!_hasAnyBackgroundImages && _isPlacementMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _placementMode = false);
      });
    }

    final pageView = PageView(
      controller: _pageController,
      onPageChanged: (i) => setState(() => _page = i),
      children: List.generate(_slides.length, (i) {
        final slide = _slides[i];

        // If offsets were not migrated yet, keep NaN in the map and convert
        // the previous alignment values to a reasonable pixel offset inside
        // _OnboardingPage (where we know the actual size).
        final storedOffsetX = _imageOffsetXMap[i];
        final storedOffsetY = _imageOffsetYMap[i];
        final legacyAlignX = _legacyAlignXMap[i];
        final legacyAlignY = _legacyAlignYMap[i];
        final scale = _imageScaleMap[i] ?? 1.0;
        return _OnboardingPage(
          controller: _pageController,
          index: i,
          isActive: i == _currentPage,
           // Background images are disabled; we use the standard SIT blurred blue backdrop.
           imagePath: null,
          defaultImageAlignment: slide.imageAlignment,
          legacyAlignment: (legacyAlignX == null || legacyAlignY == null) ? null : Alignment(legacyAlignX, legacyAlignY),
          imageOffsetX: storedOffsetX,
          imageOffsetY: storedOffsetY,
          imageScale: scale,
          placementMode: _hasAnyBackgroundImages ? _isPlacementMode : false,
          topOverlayPadding: _showTopBar ? 66 : 16,
          onPlacementChanged: (next) {
            setState(() {
              _imageOffsetXMap[i] = next.dx;
              _imageOffsetYMap[i] = next.dy;
            });
            _schedulePersistPlacement(i, next, _imageScaleMap[i] ?? 1.0);
          },
          onScaleChanged: (nextScale) {
            setState(() => _imageScaleMap[i] = nextScale);
            final offset = Offset(_imageOffsetXMap[i] ?? 0.0, _imageOffsetYMap[i] ?? 0.0);
            _schedulePersistPlacement(i, offset, nextScale);
          },
          onResetPlacement: () => _resetPlacementForSlide(i),
          onZoomIn: () => _nudgeScaleForSlide(i, 0.08),
          onZoomOut: () => _nudgeScaleForSlide(i, -0.08),
          title: slide.title,
          body: slide.body,
          bodyMaxLines: slide.bodyMaxLines,
          titleAlign: slide.titleAlign,
        );
      }),
    );

    final content = Stack(
      children: [
        Positioned.fill(child: pageView),
        const Positioned.fill(child: IgnorePointer(child: _OnboardingReadabilityOverlays())),
        SafeArea(
          child: Column(
            children: [
              if (_showTopBar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    Text('ShareItToo', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    if (widget.showTopBar ?? true)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: _hasAnyBackgroundImages ? _togglePlacementMode : null,
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                _isPlacementMode ? Icons.check_circle_outline : Icons.tune,
                                size: 14,
                                color: _hasAnyBackgroundImages ? Colors.white : Colors.white.withValues(alpha: 0.60),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isPlacementMode ? 'Fertig' : 'Bilder platzieren',
                                style: theme.textTheme.labelSmall?.copyWith(color: _hasAnyBackgroundImages ? Colors.white : Colors.white.withValues(alpha: 0.60)),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: InkWell(
                        onTap: _exitToExplore,
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.exit_to_app, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Erkunden', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
              const Spacer(),
              if (_showPageIndicator)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 2, 16, _showBottomActions ? 0 : 10),
                  child: Align(alignment: Alignment.center, child: _DotsIndicator(currentIndex: _currentPage, count: 3)),
                ),
              if (_showBottomActions)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _currentPage < 2
                        ? Column(key: const ValueKey('actions_default'), children: [
                            _NavRow(
                              left: _SecondaryCta(icon: Icons.arrow_back, label: 'Zurück', onTap: _currentPage == 0 ? null : _back),
                              right: _PrimaryCta(icon: Icons.arrow_forward, label: 'Weiter', onTap: _next, iconTrailing: true),
                            ),
                            const SizedBox(height: 10),
                            _TextLinkCta(label: 'Überspringen', onTap: _skip),
                          ])
                        : Column(key: const ValueKey('actions_auth'), children: [
                            _NavRow(
                              left: _SecondaryCta(icon: Icons.arrow_back, label: 'Zurück', onTap: _back),
                              right: _PrimaryCta(icon: Icons.person_add_alt_1, label: 'Konto erstellen', onTap: _goRegister),
                            ),
                            const SizedBox(height: 10),
                            _TextLinkCta(label: 'Schon ein Konto? Anmelden', onTap: _goLogin),
                          ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (!_wrapScaffold) return content;
    return Scaffold(backgroundColor: Colors.transparent, body: content);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: appBackgroundGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.all_inclusive, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 14),
          Text('ShareItToo', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation<Color>(BrandColors.primary),
            ),
          ),
        ]),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final PageController controller;
  final int index;
  final bool isActive;
  final String? imagePath;
  final Alignment defaultImageAlignment;
  final Alignment? legacyAlignment;
  final double? imageOffsetX;
  final double? imageOffsetY;
  final double imageScale;
  final bool placementMode;
  final double topOverlayPadding;
  final ValueChanged<Offset> onPlacementChanged;
  final ValueChanged<double> onScaleChanged;
  final VoidCallback onResetPlacement;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final String title;
  final String body;
  final int bodyMaxLines;
  final TextAlign titleAlign;
  const _OnboardingPage({required this.controller, required this.index, required this.isActive, required this.imagePath, required this.defaultImageAlignment, required this.legacyAlignment, required this.imageOffsetX, required this.imageOffsetY, required this.imageScale, required this.placementMode, required this.topOverlayPadding, required this.onPlacementChanged, required this.onScaleChanged, required this.onResetPlacement, required this.onZoomIn, required this.onZoomOut, required this.title, required this.body, required this.bodyMaxLines, required this.titleAlign});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = controller.hasClients ? (controller.page ?? controller.initialPage.toDouble()) : 0.0;
        final delta = (page - index).clamp(-1.0, 1.0);
        final t = 1.0 - delta.abs();

        // New layout: the slide image is the full-page background (no frame),
        // similar to the registration screen vibe. Text sits on top with a
        // subtle gradient/blur panel for readability.
        final backgroundShift = delta * -22;
        final textShift = delta * -10;
        return LayoutBuilder(
          builder: (context, constraints) {
            // If the stored offsets are NaN, we are coming from the previous
            // alignment-based implementation. Convert alignment -> pixel offset
            // using the current viewport size (best effort) and emit it once.
            var dx = imageOffsetX;
            var dy = imageOffsetY;
            final needsMigration = (dx == null || dy == null || dx.isNaN || dy.isNaN);
            if (needsMigration) {
              final basis = legacyAlignment ?? defaultImageAlignment;
              final fallbackDx = basis.x * (constraints.maxWidth / 2);
              final fallbackDy = basis.y * (constraints.maxHeight / 2);
              dx = fallbackDx;
              dy = fallbackDy;
              // Persist immediately so next launches are pixel-based.
              scheduleMicrotask(() => onPlacementChanged(Offset(fallbackDx, fallbackDy)));
            }

            return Stack(children: [
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(backgroundShift, 0),
                  child: _OnboardingBackgroundImage(
                    imagePath: imagePath,
                    offset: Offset(dx ?? 0.0, dy ?? 0.0),
                    scale: imageScale,
                    enabled: placementMode,
                    emphasis: t,
                    onOffsetChanged: onPlacementChanged,
                    onScaleChanged: onScaleChanged,
                  ),
                ),
              ),
          // Content (no cards; animated blur-wipe reveal)
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, topOverlayPadding, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Transform.translate(
                        offset: Offset(textShift, 0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: _BlurWipeReveal(
                            isActive: isActive,
                              child: _OnboardingTextContent(title: title, body: body, bodyMaxLines: bodyMaxLines, titleAlign: titleAlign),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (placementMode) ...[
                      const SizedBox(height: 12),
                      _PlacementModePanel(onReset: onResetPlacement, onZoomIn: onZoomIn, onZoomOut: onZoomOut),
                    ],
                  ]),
                ),
              ),
            ]);
          },
        );
      },
    );
  }
}

class _OnboardingSlideData {
  final String? imagePath;
  final String title;
  final String body;
  final int bodyMaxLines;
  final TextAlign titleAlign;
  final Alignment imageAlignment;
  const _OnboardingSlideData({required this.imagePath, required this.title, required this.body, required this.bodyMaxLines, required this.titleAlign, this.imageAlignment = Alignment.center});
}

/// The standard SIT background used for onboarding/auth: a blue, blurred, branded
/// backdrop that keeps content readable without relying on per-slide images.
class _SitBlurredBlueBackdrop extends StatelessWidget {
  const _SitBlurredBlueBackdrop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    // Paint a crisp gradient first, then add blurred “light blobs” on top.
    // We avoid BackdropFilter here (no background to sample) and use ImageFiltered
    // for deterministic performance.
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: appBackgroundGradient)),
        // Subtle brand tint that makes the backdrop feel more "SIT".
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(primary, BrandColors.logoGradientStart, 0.35)!.withValues(alpha: 0.28),
                Color.lerp(secondary, BrandColors.logoGradientEnd, 0.55)!.withValues(alpha: 0.22),
              ],
            ),
          ),
        ),
        // Blurred light blobs for a premium "glass" vibe.
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
          child: Stack(
            children: [
              Positioned(
                left: -120,
                top: -140,
                child: _GlowBlob(color: BrandColors.primary.withValues(alpha: 0.55), size: 340),
              ),
              Positioned(
                right: -160,
                top: 80,
                child: _GlowBlob(color: BrandColors.logoAccent.withValues(alpha: 0.38), size: 360),
              ),
              Positioned(
                left: -80,
                bottom: -160,
                child: _GlowBlob(color: Colors.white.withValues(alpha: 0.18), size: 420),
              ),
              Positioned(
                right: -120,
                bottom: -220,
                child: _GlowBlob(color: primary.withValues(alpha: 0.24), size: 520),
              ),
            ],
          ),
        ),
        // A gentle vignette so bottom actions remain crisp.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.08),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.34),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _OnboardingBackgroundImage extends StatefulWidget {
  final String? imagePath;
  final Offset offset;
  final double? scale;
  final bool enabled;
  final double emphasis;
  final ValueChanged<Offset> onOffsetChanged;
  final ValueChanged<double>? onScaleChanged;
  const _OnboardingBackgroundImage({required this.imagePath, required this.offset, this.scale, required this.enabled, required this.emphasis, required this.onOffsetChanged, this.onScaleChanged});

  @override
  State<_OnboardingBackgroundImage> createState() => _OnboardingBackgroundImageState();
}

class _OnboardingBackgroundImageState extends State<_OnboardingBackgroundImage> {
  Offset? _lastFocal;
  double? _startScale;
  Size? _assetSize;
  ImageStream? _stream;

  @override
  void initState() {
    super.initState();
    _resolveAssetSize();
  }

  @override
  void didUpdateWidget(covariant _OnboardingBackgroundImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _assetSize = null;
      _resolveAssetSize();
    }
  }

  void _resolveAssetSize() {
    final path = widget.imagePath;
    if (path == null || path.isEmpty) {
      // No background set (yet).
      return;
    }
    try {
      final provider = AssetImage(path);
      final stream = provider.resolve(const ImageConfiguration());
      _stream = stream;
      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        if (!mounted) return;
        final img = info.image;
        setState(() => _assetSize = Size(img.width.toDouble(), img.height.toDouble()));
        stream.removeListener(listener);
      }, onError: (e, st) {
        debugPrint('[Onboarding] Failed to resolve asset size for $path: $e');
        stream.removeListener(listener);
      });
      stream.addListener(listener);
    } catch (e) {
      debugPrint('[Onboarding] Failed to start resolving asset size: $e');
    }
  }

  @override
  void dispose() {
    // Best-effort: listeners are removed after first image frame.
    _stream = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final path = widget.imagePath;

      // No asset selected: fall back to the standard SIT blurred blue backdrop.
      if (path == null || path.isEmpty) {
        return const _SitBlurredBlueBackdrop();
      }

      // User scale is persisted (1.0 = default). We additionally apply a
      // computed base scale so the full asset is visible by default
      // ("komplett zoomed out" / BoxFit.contain behavior) without cropping.
      final userScale = (widget.scale ?? 1.0).clamp(0.25, 3.50);
      final assetSize = _assetSize;
      final viewportW = constraints.maxWidth == 0 ? 1.0 : constraints.maxWidth;
      final viewportH = constraints.maxHeight == 0 ? 1.0 : constraints.maxHeight;
      var containScale = 1.0;
      if (assetSize != null && assetSize.width > 0 && assetSize.height > 0) {
        containScale = (viewportW / assetSize.width).clamp(0.0, double.infinity);
        containScale = _minDouble(containScale, viewportH / assetSize.height);
        // If the asset is smaller than the viewport, don't auto-upscale.
        containScale = _minDouble(containScale, 1.0);
        // Give a tiny extra margin so edges never look clipped.
        containScale *= 0.98;
      }
      final effectiveScale = (containScale * userScale).clamp(0.20, 3.80);

      final image = ColoredBox(
        color: Colors.black,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          scale: 1.01 + (0.02 * widget.emphasis),
          child: Transform.translate(
            offset: widget.offset,
            child: Transform.scale(
              scale: effectiveScale,
              alignment: Alignment.center,
              child: Image.asset(path, fit: BoxFit.none, filterQuality: FilterQuality.high),
            ),
          ),
        ),
      );

      if (!widget.enabled) return image;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (d) {
          _lastFocal = d.localFocalPoint;
          _startScale = userScale;
        },
        onScaleUpdate: (d) {
          final lastFocal = _lastFocal;
          final startScale = _startScale;
          if (lastFocal == null || startScale == null) return;

          // Scale: pinch to zoom (persisted user scale; containScale is applied on top)
          final nextUserScale = (startScale * d.scale).clamp(0.25, 3.50);
          widget.onScaleChanged?.call(nextUserScale);

          // Translation: move image freely with the same gesture.
          final deltaPx = d.localFocalPoint - lastFocal;
          _lastFocal = d.localFocalPoint;

          // Pixel offset: allow moving further than the viewport edges.
          // We clamp to a generous range to prevent accidental extreme values.
          final next = Offset(
            (widget.offset.dx + deltaPx.dx).clamp(-viewportW * 2.0, viewportW * 2.0),
            (widget.offset.dy + deltaPx.dy).clamp(-viewportH * 2.0, viewportH * 2.0),
          );
          widget.onOffsetChanged(next);
        },
        child: image,
      );
    });
  }
}

double _minDouble(double a, double b) => a < b ? a : b;

class _OnboardingReadabilityOverlays extends StatelessWidget {
  const _OnboardingReadabilityOverlays();

  @override
  Widget build(BuildContext context) {
    // Similar “vibe” to the registration backdrop: gradients + subtle tint.
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.68),
                  Colors.black.withValues(alpha: 0.12),
                  Colors.black.withValues(alpha: 0.82),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.9),
                radius: 1.15,
                colors: [Colors.white.withValues(alpha: 0.10), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingTextContent extends StatelessWidget {
  final String title;
  final String body;
  final int bodyMaxLines;
  final TextAlign titleAlign;
  const _OnboardingTextContent({required this.title, required this.body, required this.bodyMaxLines, required this.titleAlign});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(
        title,
        textAlign: titleAlign,
        style: theme.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          height: 1.06,
          fontSize: 30,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 26, offset: Offset(0, 10)),
            Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Text(
        body,
        textAlign: TextAlign.center,
        maxLines: bodyMaxLines,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          height: 1.55,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, 10)),
            Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
      ),
    ]);
  }
}

class _BlurWipeReveal extends StatefulWidget {
  final bool isActive;
  final Widget child;
  const _BlurWipeReveal({required this.isActive, required this.child});

  @override
  State<_BlurWipeReveal> createState() => _BlurWipeRevealState();
}

class _BlurWipeRevealState extends State<_BlurWipeReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 760));
    if (widget.isActive) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant _BlurWipeReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward(from: 0);
    }
    if (!widget.isActive && oldWidget.isActive) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final v = curved.value;
        final heightFactor = (0.10 + (0.90 * v)).clamp(0.0, 1.0);
        final sigma = lerpDouble(18, 0, v) ?? 0;
        final y = lerpDouble(44, 0, v) ?? 0;
        final opacity = lerpDouble(0.0, 1.0, v) ?? 1.0;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, y),
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: heightFactor,
                child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: child),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _PlacementModePanel extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  const _PlacementModePanel({required this.onReset, required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(children: [
                const Icon(Icons.open_with, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(child: Text('Ziehen oder pinchen zum Zoomen', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      InkWell(
        onTap: onZoomOut,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Icon(Icons.remove, size: 18, color: Colors.white),
        ),
      ),
      const SizedBox(width: 10),
      InkWell(
        onTap: onZoomIn,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Icon(Icons.add, size: 18, color: Colors.white),
        ),
      ),
      const SizedBox(width: 10),
      InkWell(
        onTap: onReset,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Icon(Icons.refresh, size: 18, color: Colors.white),
        ),
      ),
    ]);
  }
}

class _PrimaryCta extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool iconTrailing;
  const _PrimaryCta({required this.icon, required this.label, required this.onTap, this.iconTrailing = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: appBackgroundGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: iconTrailing
              ? [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(label, textAlign: TextAlign.right, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(icon, color: Colors.white, size: 20),
                ]
              : [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900))),
                ],
        ),
      ),
    );
  }
}

class _SecondaryCta extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SecondaryCta({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: enabled ? 0.05 : 0.0)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.08)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Icon(icon, color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.55), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.55), fontWeight: FontWeight.w800),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _NavRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: left),
      const SizedBox(width: 10),
      Expanded(child: right),
    ]);
  }
}

class _DotsIndicator extends StatelessWidget {
  final int currentIndex;
  final int count;
  final double emphasis;
  const _DotsIndicator({required this.currentIndex, required this.count, this.emphasis = 1.0});

  @override
  Widget build(BuildContext context) {
    final active = Colors.white;
    final inactive = Colors.white.withValues(alpha: 0.28);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(right: i == count - 1 ? 0 : 7),
          width: isActive ? 22 : 9,
          height: 9,
          decoration: BoxDecoration(
            color: (isActive ? active : inactive).withValues(alpha: (isActive ? 1.0 : 1.0) * (0.82 + (0.18 * emphasis))),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _TextLinkCta extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _TextLinkCta({required this.label, required this.onTap});

  @override
  State<_TextLinkCta> createState() => _TextLinkCtaState();
}

class _TextLinkCtaState extends State<_TextLinkCta> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: _hovering ? 1.0 : 0.86,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(widget.label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}
