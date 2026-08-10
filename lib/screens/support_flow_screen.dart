import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lendify/theme.dart';

/// Quelle, aus der der Support-Flow gestartet wurde
enum SupportFlowSource {
  bookingChat,
  bookingDetail,
  ownerRequestDetail,
}

/// Rolle des aktuellen Nutzers
enum SupportFlowRole {
  renter,
  owner,
}

/// Kontext-Modell für den Support-Flow
class SupportFlowContext {
  final String itemTitle;
  final String itemId;
  final String requestId;
  final String bookingStatus;
  final SupportFlowSource source;
  final SupportFlowRole role;
  final String? otherUserName;
  final String? threadId;
  final String? itemImageUrl;
  final String? otherUserImageUrl;

  const SupportFlowContext({
    required this.itemTitle,
    required this.itemId,
    required this.requestId,
    required this.bookingStatus,
    required this.source,
    required this.role,
    this.otherUserName,
    this.threadId,
    this.itemImageUrl,
    this.otherUserImageUrl,
  });
  
  /// Factory für Chat-Kontext
  factory SupportFlowContext.fromChat({
    required String itemTitle,
    required String itemId,
    required String requestId,
    required String bookingStatus,
    required bool viewerIsOwner,
    String? otherUserName,
    String? threadId,
    String? itemImageUrl,
    String? otherUserImageUrl,
  }) {
    return SupportFlowContext(
      itemTitle: itemTitle,
      itemId: itemId,
      requestId: requestId,
      bookingStatus: bookingStatus,
      source: SupportFlowSource.bookingChat,
      role: viewerIsOwner ? SupportFlowRole.owner : SupportFlowRole.renter,
      otherUserName: otherUserName,
      threadId: threadId,
      itemImageUrl: itemImageUrl,
      otherUserImageUrl: otherUserImageUrl,
    );
  }
  
  /// Factory für Buchungsdetail-Kontext
  factory SupportFlowContext.fromBookingDetail({
    required String itemTitle,
    required String itemId,
    required String requestId,
    required String bookingStatus,
    required bool viewerIsOwner,
    String? otherUserName,
    String? itemImageUrl,
    String? otherUserImageUrl,
  }) {
    return SupportFlowContext(
      itemTitle: itemTitle,
      itemId: itemId,
      requestId: requestId,
      bookingStatus: bookingStatus,
      source: SupportFlowSource.bookingDetail,
      role: viewerIsOwner ? SupportFlowRole.owner : SupportFlowRole.renter,
      otherUserName: otherUserName,
      itemImageUrl: itemImageUrl,
      otherUserImageUrl: otherUserImageUrl,
    );
  }
  
  /// Factory für Owner-Request-Detail-Kontext
  factory SupportFlowContext.fromOwnerRequestDetail({
    required String itemTitle,
    required String itemId,
    required String requestId,
    required String bookingStatus,
    String? otherUserName,
    String? itemImageUrl,
    String? otherUserImageUrl,
  }) {
    return SupportFlowContext(
      itemTitle: itemTitle,
      itemId: itemId,
      requestId: requestId,
      bookingStatus: bookingStatus,
      source: SupportFlowSource.ownerRequestDetail,
      role: SupportFlowRole.owner,
      otherUserName: otherUserName,
      itemImageUrl: itemImageUrl,
      otherUserImageUrl: otherUserImageUrl,
    );
  }
  
  /// Konvertiert den Kontext zu einer Map für den Support-Fall
  Map<String, dynamic> toSupportContext() {
    return {
      'itemTitle': itemTitle,
      'itemId': itemId,
      'requestId': requestId,
      'threadId': threadId ?? '',
      'bookingStatus': bookingStatus,
      'otherUserName': otherUserName ?? '',
      'currentUserRole': role == SupportFlowRole.owner ? 'owner' : 'renter',
      'source': source.name,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}

/// Ergebnis des Support-Flows
class SupportFlowResult {
  final String mainCategory;
  final String subCategory;
  final String userDescription;
  final SupportFlowContext context;

  const SupportFlowResult({
    required this.mainCategory,
    required this.subCategory,
    required this.userDescription,
    required this.context,
  });
  
  /// Konvertiert zu einer Map
  Map<String, dynamic> toMap() {
    return {
      'mainCategory': mainCategory,
      'subCategory': subCategory,
      'userDescription': userDescription,
      ...context.toSupportContext(),
    };
  }
  
  /// Menschenlesbare Kategorie-Bezeichnung
  String get mainCategoryLabel {
    switch (mainCategory) {
      case 'handover': return 'Problem mit Übergabe';
      case 'return': return 'Problem mit Rückgabe';
      case 'item_condition': return 'Problem mit Artikel/Zustand';
      case 'payment': return 'Problem mit Zahlung';
      case 'person': return 'Problem mit anderer Person';
      case 'technical': return 'Technisches Problem';
      case 'other': return 'Sonstiges';
      case 'profile_report': return 'Profil melden';
      default: return mainCategory;
    }
  }
}

/// Fullscreen Support-Kategorie-Auswahl-Seite
/// Wiederverwendbar aus Chat-Menü und Buchungsdetails
class SupportFlowScreen extends StatefulWidget {
  final SupportFlowContext context;

  const SupportFlowScreen({
    super.key,
    required this.context,
  });
  
  /// Legacy-Konstruktor für Kompatibilität mit bestehendem Code
  factory SupportFlowScreen.legacy({
    required String itemTitle,
    required String itemId,
    required String requestId,
    required String bookingStatus,
  }) {
    return SupportFlowScreen(
      context: SupportFlowContext(
        itemTitle: itemTitle,
        itemId: itemId,
        requestId: requestId,
        bookingStatus: bookingStatus,
        source: SupportFlowSource.bookingChat,
        role: SupportFlowRole.renter,
      ),
    );
  }

  @override
  State<SupportFlowScreen> createState() => _SupportFlowScreenState();
}

class _SupportFlowScreenState extends State<SupportFlowScreen> {
  String? _selectedMainCategory;
  String? _selectedSubCategory;
  String? _selectedDetailSubCategory;
  final _descriptionController = TextEditingController();
  bool _sendingSupport = false;
  bool _cardsHidden = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // Menschliche Titel/Sublines pro Hauptkategorie
  static const _categoryTitles = <String, Map<String, String>>{
    'handover': {
      'title': 'Hast du ein Problem mit der Übergabe?',
      'subline': 'Wir helfen dir gerne dabei. Wähle den Grund, der am besten passt.',
    },
    'return': {
      'title': 'Hast du ein Problem mit der Rückgabe?',
      'subline': 'Wir helfen dir gerne dabei. Wähle den genauesten Grund, damit wir schneller reagieren können.',
    },
    'item_condition': {
      'title': 'Gibt es ein Problem mit dem Artikel?',
      'subline': 'Beschreibe zuerst den passenden Grund. So kann der Support den Zustand besser einordnen.',
    },
    'payment': {
      'title': 'Gibt es ein Problem mit der Zahlung?',
      'subline': 'Wähle den passenden Zahlungsgrund, damit wir den Fall schneller prüfen können.',
    },
    'person': {
      'title': 'Gibt es ein Problem mit der anderen Person?',
      'subline': 'Wenn du dich unwohl fühlst oder etwas nicht stimmt, wähle bitte den genauesten Grund.',
    },
    'technical': {
      'title': 'Gibt es ein technisches Problem?',
      'subline': 'Wähle, was nicht funktioniert. So können wir den Fehler schneller finden.',
    },
    'other': {
      'title': 'Wobei brauchst du Hilfe?',
      'subline': 'Wähle den passendsten Grund oder beschreibe dein Anliegen im nächsten Schritt.',
    },
  };

  static const _categories = <String, _SupportCategory>{
    'handover': _SupportCategory(
      icon: Icons.inventory_2_outlined,
      label: 'Problem mit Übergabe',
      subcategories: [
        'Mieter ist nicht erschienen',
        'Vermieter ist nicht erschienen',
        'Gegenpartei öffnet nicht / reagiert nicht',
        'Übergabeort ist unklar',
        'Falsche Person ist erschienen',
        'Artikel ist nicht wie beschrieben',
        'Vermieter verweigert Übergabe',
        'Mieter verweigert Bestätigung',
        'QR-Code funktioniert nicht',
        '6-stelliger Code funktioniert nicht',
        'Kamera/Fotos funktionieren nicht',
        'Ich fühle mich unsicher vor Ort',
        'Sonstiges Übergabeproblem',
      ],
    ),
    'return': _SupportCategory(
      icon: Icons.assignment_return_outlined,
      label: 'Problem mit Rückgabe',
      subcategories: [
        'Mieter ist nicht zur Rückgabe erschienen',
        'Vermieter ist nicht zur Rückgabe erschienen',
        'Gegenpartei reagiert nicht',
        'Rückgabeort ist unklar',
        'Artikel wurde beschädigt zurückgegeben',
        'Artikel fehlt / wurde nicht zurückgegeben',
        'Rückgabe wird verweigert',
        'QR-Code funktioniert nicht',
        '6-stelliger Rückgabecode funktioniert nicht',
        'Rückgabefotos funktionieren nicht',
        'Ich fühle mich unsicher vor Ort',
        'Sonstiges Rückgabeproblem',
      ],
    ),
    'item_condition': _SupportCategory(
      icon: Icons.warning_amber_outlined,
      label: 'Problem mit Artikel/Zustand',
      subcategories: [
        'Artikel funktioniert nicht',
        'Artikel ist beschädigt',
        'Zubehör fehlt',
        'Artikel entspricht nicht der Beschreibung',
        'Artikel war schmutzig',
        'Falscher Artikel übergeben',
        'Schaden wurde schon vor Übergabe bemerkt',
        'Schaden wurde nach Rückgabe gemeldet',
        'Sonstiges Artikelproblem',
      ],
    ),
    'payment': _SupportCategory(
      icon: Icons.payments_outlined,
      label: 'Problem mit Zahlung',
      subcategories: [
        'Preis stimmt nicht',
        'Kaution / Sicherheitsbetrag unklar',
        'Zahlung wurde doppelt angezeigt',
        'Rückerstattung unklar',
        'Auszahlung unklar',
        'Stornierung und Zahlung unklar',
        'Gebühren unklar',
        'Sonstiges Zahlungsproblem',
      ],
    ),
    'person': _SupportCategory(
      icon: Icons.person_off_outlined,
      label: 'Problem mit anderer Person',
      subcategories: [
        'Unangemessenes Verhalten',
        'Drohung / Druck',
        'Beleidigung',
        'Verdächtiges Verhalten',
        'Profil wirkt falsch',
        'Andere Person will außerhalb von SIT abwickeln',
        'Sicherheitsgefühl vor Ort schlecht',
        'Sonstiges Personenproblem',
      ],
    ),
    'technical': _SupportCategory(
      icon: Icons.bug_report_outlined,
      label: 'Technisches Problem',
      subcategories: [
        'Chat funktioniert nicht',
        'Kamera funktioniert nicht',
        'Datei hochladen funktioniert nicht',
        'Standort senden funktioniert nicht',
        'QR-Code Scanner funktioniert nicht',
        'App lädt nicht',
        'Button reagiert nicht',
        'Sonstiges technisches Problem',
      ],
    ),
    'other': _SupportCategory(
      icon: Icons.more_horiz_rounded,
      label: 'Sonstiges',
      subcategories: [
        'Ich bin unsicher, was ich tun soll',
        'Allgemeine Frage zur Buchung',
        'Ich brauche Hilfe vom Support',
        'Profil melden',
        'Anderes Problem',
      ],
    ),
  };

  bool get _isProfileContext => widget.context.requestId.startsWith('profile:') || widget.context.itemId.startsWith('profile:');

  bool get _needsProfileReasonStep => _isProfileContext && _selectedMainCategory == 'other' && _selectedSubCategory == 'Profil melden';

  static const List<String> _profileReportReasons = [
    'Falsche Identität',
    'Unangemessenes Verhalten',
    'Betrugsverdacht',
    'Beleidigende/gefährliche Inhalte',
    'Spam',
    'Sonstiges',
  ];

  void _handleBack() {
    if (_selectedDetailSubCategory != null) {
      setState(() => _selectedDetailSubCategory = null);
    } else if (_selectedSubCategory != null) {
      setState(() => _selectedSubCategory = null);
    } else if (_selectedMainCategory != null) {
      setState(() => _selectedMainCategory = null);
    } else {
      Navigator.of(context).pop();
    }
  }

  String _currentTitle() {
    if (_selectedDetailSubCategory != null) return 'Beschreibe kurz, was passiert ist';
    if (_needsProfileReasonStep) return 'Warum möchtest du dieses Profil melden?';
    if (_selectedSubCategory != null) return 'Beschreibe kurz, was passiert ist';
    if (_selectedMainCategory != null) {
      return _categoryTitles[_selectedMainCategory]?['title'] ?? 'Wähle einen Grund';
    }
    return 'Wobei brauchst du Hilfe?';
  }

  String _currentSubline() {
    if (_selectedDetailSubCategory != null) return 'Prüfe die Auswahl kurz und beschreibe danach den Fall für den Support.';
    if (_needsProfileReasonStep) return 'Wähle den genauesten Grund, damit der Support den Fall richtig einordnen kann.';
    if (_selectedSubCategory != null) return 'Je genauer du es beschreibst, desto schneller kann dir der Support helfen.';
    if (_selectedMainCategory != null) {
      return _categoryTitles[_selectedMainCategory]?['subline'] ?? 'Wähle den genauesten Grund.';
    }
    return 'Wähle den genauesten Grund, damit wir dir schneller helfen können.';
  }

  void _toggleCardsVisibility() {
    setState(() => _cardsHidden = !_cardsHidden);
    // Nach 2.5s automatisch wieder einblenden
    if (_cardsHidden) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _cardsHidden) setState(() => _cardsHidden = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final dark = theme.colorScheme.secondary;
    final isDark = theme.brightness == Brightness.dark;
    final isMainCategoryPage = _selectedMainCategory == null && _selectedSubCategory == null;
    final isSubcategoryPage = _selectedMainCategory != null && _selectedSubCategory == null;
    final shouldCenterTitle = isMainCategoryPage || isSubcategoryPage;

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : AppTheme.surfaceMuted(context),
      body: GestureDetector(
        // Tap außerhalb der Cards = Hintergrund-Preview
        onTap: () {
          // Nur im Dark Theme und nur auf Hauptkategorie/Subkategorie-Seite aktivieren
          if (isDark && _selectedSubCategory == null) _toggleCardsVisibility();
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // SIT Background - Support background
            if (isDark)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Hintergrund_Support.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            if (!isDark)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.surfaceMuted(context),
                        AppTheme.surfacePrimary(context),
                      ],
                    ),
                  ),
                ),
              ),
            // Base blur - reduziert bei Background-Preview
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _cardsHidden ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: isDark ? 14 : 6, sigmaY: isDark ? 14 : 6),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            // Leichter Blur bleibt bei Background-Preview für sanften Look
            if (_cardsHidden)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: isDark ? 2 : 1, sigmaY: isDark ? 2 : 1),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            // Dunkler Color tint overlay - stark reduziert bei Background-Preview
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _cardsHidden ? 0.15 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Color.lerp(primary, BrandColors.logoGradientStart, 0.35)!.withValues(alpha: 0.45),
                              Color.lerp(dark, BrandColors.logoGradientEnd, 0.55)!.withValues(alpha: 0.38),
                            ]
                          : [
                              BrandColors.primary.withValues(alpha: 0.06),
                              const Color(0xFFF8FAFC),
                            ],
                    ),
                  ),
                ),
              ),
            ),
            // Top gradient overlay - reduziert bei Background-Preview
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _cardsHidden ? 0.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                Colors.black.withValues(alpha: 0.78),
                                Colors.black.withValues(alpha: 0.62),
                                Colors.black.withValues(alpha: 0.38),
                                Colors.black.withValues(alpha: 0.18),
                                Colors.transparent,
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.68),
                                Colors.white.withValues(alpha: 0.38),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.transparent,
                              ],
                        stops: const [0.0, 0.06, 0.14, 0.24, 0.40],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom gradient overlay - reduziert bei Background-Preview
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _cardsHidden ? 0.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.12),
                                Colors.black.withValues(alpha: 0.28),
                                Colors.black.withValues(alpha: 0.48),
                                Colors.black.withValues(alpha: 0.65),
                                Colors.black.withValues(alpha: 0.80),
                              ]
                            : [
                                Colors.transparent,
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.12),
                                Colors.white.withValues(alpha: 0.26),
                                Colors.white.withValues(alpha: 0.42),
                                Colors.white.withValues(alpha: 0.56),
                                Colors.white.withValues(alpha: 0.72),
                              ],
                        stops: const [0.0, 0.50, 0.64, 0.75, 0.84, 0.92, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Content - mit AnimatedOpacity für Card-Hide-Feature
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header mit Back-Button - immer sichtbar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          onPressed: _handleBack,
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: isDark ? Colors.white.withValues(alpha: 0.9) : AppTheme.textPrimary(context),
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        // SIT Logo
                        ClipOval(
                          child: Image.asset(
                            'assets/images/icononly_transparent_nobuffer.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                  // Titel-Sektion - zentriert auf Hauptkategorie- und Subkategorie-Seite
                  AnimatedOpacity(
                    opacity: _cardsHidden ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: shouldCenterTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentTitle(),
                            textAlign: shouldCenterTitle ? TextAlign.center : TextAlign.start,
                            style: TextStyle(
                              color: isDark ? Colors.white.withValues(alpha: 0.95) : AppTheme.textPrimary(context),
                              fontWeight: FontWeight.w800,
                              fontSize: shouldCenterTitle ? 26 : 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentSubline(),
                            textAlign: shouldCenterTitle ? TextAlign.center : TextAlign.start,
                            style: TextStyle(
                              color: isDark ? Colors.white.withValues(alpha: 0.55) : AppTheme.textBody(context),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Buchungs-Kontextkarte - immer sichtbar für Kontext
                  if (widget.context.requestId.isNotEmpty || widget.context.itemTitle.isNotEmpty)
                    AnimatedOpacity(
                      opacity: _cardsHidden ? 0.15 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _DistinctBookingContextCard(
                          itemTitle: widget.context.itemTitle,
                          itemId: widget.context.itemId,
                          requestId: widget.context.requestId,
                          bookingStatus: widget.context.bookingStatus,
                          otherUserName: widget.context.otherUserName,
                          itemImageUrl: widget.context.itemImageUrl,
                          otherUserImageUrl: widget.context.otherUserImageUrl,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Content: Categories oder Description
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _cardsHidden ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: _cardsHidden,
                        child: _selectedDetailSubCategory != null
                            ? _buildDescriptionStep()
                            : _needsProfileReasonStep
                                ? _buildProfileReportReasons()
                                : _selectedSubCategory != null
                                    ? _buildDescriptionStep()
                                    : _selectedMainCategory == null
                                        ? _buildMainCategories()
                                        : _buildSubcategories(_selectedMainCategory!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Hint bei versteckten Cards
            if (_cardsHidden)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _cardsHidden ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withValues(alpha: 0.55) : AppTheme.surfacePrimary(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : AppTheme.glassStroke(context)),
                      ),
                      child: Text(
                        'Tippe erneut, um fortzufahren',
                        style: TextStyle(
                          color: isDark ? Colors.white.withValues(alpha: 0.8) : AppTheme.textPrimary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
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

  Widget _buildMainCategories() {
    // Kategorien gleichmäßig verteilt über verfügbaren Bereich
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final cardCount = _categories.length;
        // Mindestens 54px pro Card, plus dynamischen Abstand
        final minCardHeight = 58.0;
        final totalMinHeight = cardCount * minCardHeight;
        final dynamicSpacing = ((availableHeight - totalMinHeight - 32) / (cardCount - 1)).clamp(10.0, 22.0);
        
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          physics: availableHeight > totalMinHeight + (cardCount - 1) * 10
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => SizedBox(height: dynamicSpacing),
          itemBuilder: (context, index) {
            final key = _categories.keys.elementAt(index);
            final cat = _categories[key]!;
            return _GlassySupportCategoryCard(
              icon: cat.icon,
              label: cat.label,
              showChevron: true,
              onTap: () => setState(() => _selectedMainCategory = key),
            );
          },
        );
      },
    );
  }

  Widget _buildSubcategories(String mainKey) {
    final cat = _categories[mainKey]!;
    final subcategories = mainKey == 'other' && !_isProfileContext
        ? cat.subcategories.where((sub) => sub != 'Profil melden').toList()
        : cat.subcategories;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: subcategories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final sub = subcategories[index];
        return _GlassySubcategoryCard(
          label: sub,
          onTap: () => setState(() {
            _selectedSubCategory = sub;
            _selectedDetailSubCategory = null;
          }),
        );
      },
    );
  }

  Widget _buildProfileReportReasons() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _profileReportReasons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final reason = _profileReportReasons[index];
        return _GlassySubcategoryCard(
          label: reason,
          onTap: () => setState(() => _selectedDetailSubCategory = reason),
        );
      },
    );
  }

  Widget _buildDescriptionStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedMainCategory = (_needsProfileReasonStep || _selectedDetailSubCategory != null)
        ? 'profile_report'
        : _selectedMainCategory;
    final resolvedSubCategory = _selectedDetailSubCategory ?? _selectedSubCategory;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _SupportPreviewCard(
            mainCategory: resolvedMainCategory ?? '',
            subCategory: resolvedSubCategory ?? '',
            itemTitle: widget.context.itemTitle,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : AppTheme.surfacePrimary(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD9E2EC)),
                  ),
                  child: TextField(
                    controller: _descriptionController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.95) : AppTheme.textPrimary(context),
                      fontSize: 15,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Was ist passiert? Beschreibe die Situation so genau wie möglich …',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white.withValues(alpha: 0.35) : AppTheme.textDisabled(context),
                        fontSize: 15,
                      ),
                      contentPadding: const EdgeInsets.all(18),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Send button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: _SupportPressScale(
              onTap: _sendingSupport ? null : _submitSupportCase,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          BrandColors.primary,
                          BrandColors.primary.withValues(alpha: 0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Center(
                      child: _sendingSupport
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.white.withValues(alpha: 0.9) : AppTheme.textPrimary(context),
                              ),
                            )
                          : const Text(
                              'An Support schicken',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _submitSupportCase() async {
    if (_sendingSupport) return;
    setState(() => _sendingSupport = true);

    try {
      // Return SupportFlowResult mit allen Daten
      final result = SupportFlowResult(
        mainCategory: (_needsProfileReasonStep || _selectedDetailSubCategory != null) ? 'profile_report' : (_selectedMainCategory ?? ''),
        subCategory: _selectedDetailSubCategory ?? _selectedSubCategory ?? '',
        userDescription: _descriptionController.text.trim(),
        context: widget.context,
      );
      Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _sendingSupport = false);
    }
  }
}

class _SupportPreviewCard extends StatelessWidget {
  final String mainCategory;
  final String subCategory;
  final String itemTitle;

  const _SupportPreviewCard({
    required this.mainCategory,
    required this.subCategory,
    required this.itemTitle,
  });

  String _categoryLabel(String value) {
    switch (value) {
      case 'handover': return 'Problem mit Übergabe';
      case 'return': return 'Problem mit Rückgabe';
      case 'item_condition': return 'Problem mit Artikel/Zustand';
      case 'payment': return 'Problem mit Zahlung';
      case 'person': return 'Problem mit anderer Person';
      case 'technical': return 'Technisches Problem';
      case 'other': return 'Sonstiges';
      case 'profile_report': return 'Profil melden';
      default: return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : AppTheme.surfacePrimary(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : AppTheme.glassStroke(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vorschau für den Support', style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.92) : AppTheme.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Kontext: $itemTitle', style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.78) : AppTheme.textSecondary(context), fontSize: 13)),
          const SizedBox(height: 4),
          Text('Kategorie: ${_categoryLabel(mainCategory)}', style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.78) : AppTheme.textSecondary(context), fontSize: 13)),
          const SizedBox(height: 4),
          Text('Grund: $subCategory', style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.78) : AppTheme.textSecondary(context), fontSize: 13)),
        ],
      ),
    );
  }
}

class _SupportCategory {
  final IconData icon;
  final String label;
  final List<String> subcategories;

  const _SupportCategory({
    required this.icon,
    required this.label,
    required this.subcategories,
  });
}

/// Distinkte Buchungs-Kontextkarte - Premium Glass-Look
/// Mit quadratischem Artikelbild + Nutzer-Avatar-Overlay
class _DistinctBookingContextCard extends StatelessWidget {
  final String itemTitle;
  final String itemId;
  final String requestId;
  final String bookingStatus;
  final String? otherUserName;
  final String? itemImageUrl;
  final String? otherUserImageUrl;

  const _DistinctBookingContextCard({
    required this.itemTitle,
    required this.itemId,
    required this.requestId,
    required this.bookingStatus,
    this.otherUserName,
    this.itemImageUrl,
    this.otherUserImageUrl,
  });

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'Angefragt';
      case 'accepted': return 'Bestätigt';
      case 'running': return 'Laufend';
      case 'completed': return 'Abgeschlossen';
      case 'declined': return 'Abgelehnt';
      case 'cancelled': return 'Storniert';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'running': return BrandColors.primary;
      case 'completed': return Colors.teal;
      case 'declined': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return BrandColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusCol = _statusColor(bookingStatus);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.03),
                    ]
                  : [
                      AppTheme.surfacePrimary(context),
                      AppTheme.surfaceSecondary(context),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFD9E2EC),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05),
                blurRadius: isDark ? 20 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Quadratisches Artikelbild mit Nutzer-Avatar-Overlay
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Artikel-Bild (quadratisch) - echtes Bild oder Placeholder
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: itemImageUrl == null || itemImageUrl!.isEmpty
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                BrandColors.primary.withValues(alpha: 0.22),
                                BrandColors.primary.withValues(alpha: 0.08),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BrandColors.primary.withValues(alpha: 0.18)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: itemImageUrl != null && itemImageUrl!.isNotEmpty
                        ? Image.network(
                            itemImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.inventory_2_rounded,
                                color: BrandColors.primary.withValues(alpha: 0.75),
                                size: 24,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.inventory_2_rounded,
                              color: BrandColors.primary.withValues(alpha: 0.75),
                              size: 24,
                            ),
                          ),
                  ),
                  // Kleiner Nutzer-Avatar-Overlay unten rechts - echtes Bild oder Placeholder
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.grey.shade800 : AppTheme.surfacePrimary(context),
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: otherUserImageUrl != null && otherUserImageUrl!.isNotEmpty
                          ? Image.network(
                              otherUserImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  color: isDark ? Colors.white.withValues(alpha: 0.7) : AppTheme.textSecondary(context),
                                  size: 14,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.person_rounded,
                                color: isDark ? Colors.white.withValues(alpha: 0.7) : AppTheme.textSecondary(context),
                                size: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Info-Bereich
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (itemTitle.isNotEmpty)
                      Text(
                        itemTitle,
                        style: TextStyle(
                          color: isDark ? Colors.white.withValues(alpha: 0.95) : AppTheme.textPrimary(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 3),
                    // Gegenüber + Buchungs-ID
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          color: isDark ? Colors.white.withValues(alpha: 0.45) : AppTheme.textSecondary(context),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            otherUserName ?? 'Gegenpartei',
                            style: TextStyle(
                              color: isDark ? Colors.white.withValues(alpha: 0.50) : AppTheme.textSecondary(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (requestId.isNotEmpty)
                          Text(
                            '#${requestId.length > 6 ? requestId.substring(0, 6) : requestId}',
                            style: TextStyle(
                              color: isDark ? Colors.white.withValues(alpha: 0.35) : AppTheme.textDisabled(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status-Chip rechts
              if (bookingStatus.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusCol.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusCol.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    _statusLabel(bookingStatus),
                    style: TextStyle(
                      color: statusCol,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glassy Category card für Hauptkategorien - SIT Style
class _GlassySupportCategoryCard extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool showChevron;
  final VoidCallback onTap;

  const _GlassySupportCategoryCard({
    required this.icon,
    required this.label,
    required this.showChevron,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SupportPressScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.045) : AppTheme.surfacePrimary(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD9E2EC)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          BrandColors.primary.withValues(alpha: 0.18),
                          BrandColors.primary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BrandColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Center(
                      child: Icon(icon, color: BrandColors.primary, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.92) : AppTheme.textPrimary(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (showChevron)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white.withValues(alpha: 0.4) : AppTheme.textSecondary(context),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Leichtere Glassy Card für Subkategorien - unterscheidet sich von Hauptkategorien
class _GlassySubcategoryCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GlassySubcategoryCard({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SupportPressScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              // Transparenter und leichter als Hauptkategorien
              color: isDark ? Colors.white.withValues(alpha: 0.035) : AppTheme.surfacePrimary(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFD9E2EC)),
            ),
            child: Row(
              children: [
                // Kleiner Punkt-Indikator statt Icon
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? BrandColors.primary.withValues(alpha: 0.6) : BrandColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.88) : AppTheme.textPrimary(context),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white.withValues(alpha: 0.32) : AppTheme.textSecondary(context),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PressScale Widget für Support-Flow
class _SupportPressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _SupportPressScale({required this.child, required this.onTap});

  @override
  State<_SupportPressScale> createState() => _SupportPressScaleState();
}

class _SupportPressScaleState extends State<_SupportPressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
