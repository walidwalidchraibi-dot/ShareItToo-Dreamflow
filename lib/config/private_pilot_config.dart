class PrivatePilotConfig {
  PrivatePilotConfig._();

  static const bool enabled = true;
  static const bool deliveryEnabled = false;
  static const bool aiFeaturesEnabled = false;

  /// Until the four legal checkout questions are answered, the pilot may show
  /// a complete checkout preview but must not create a binding request or
  /// start a payment from that preview.
  static const bool bindingCheckoutEnabled = true;

  /// V4 interim model. These values are versioned and intentionally isolated
  /// so later legal feedback changes one source instead of scattered screens.
  static const bool interimLegalModelEnabled = true;
  static const bool realPaymentsEnabled = false;
  static const String plannedMarketplacePaymentProvider =
      'Stripe Connect (Testkonfiguration; Vertragspartner und Geldfluss vor Livegang erneut verifizieren)';
  static const String bindingRequestDeclaration =
      'Ich gebe eine verbindliche zahlungspflichtige Buchungsanfrage zu den angezeigten Daten, Preisen und Dokumentversionen ab.';
  static const String platformTermsDeclaration =
      'Ich akzeptiere die Plattform-Nutzungsbedingungen und den angezeigten Plattformbeitrag.';
  static const String earlyPerformanceDeclaration =
      'Ich verlange, dass ShareItToo vor Ablauf der Widerrufsfrist mit der Vermittlung und technischen Buchungsbestätigung beginnt.';
  static const String withdrawalKnowledgeDeclaration =
      'Mir ist bekannt, dass mein Widerrufsrecht bei vollständiger Vertragserfüllung unter den gesetzlichen Voraussetzungen erlöschen kann.';
  static const String ownerAcceptanceDeclaration =
      'Ich nehme die zahlungspflichtige Buchungsanfrage zu den angezeigten Bedingungen und Dokumentversionen an.';
  static const String platformWithdrawalDeclaration =
      'Ich widerrufe die kostenpflichtige Plattformleistung von ShareItToo für die ausgewählte Buchung.';
  static const int bookingRequestBindingHours = 24;

  static const int platformFeeBasisPoints = 1000; // 10.00%
  static const int returnReportWindowHours = 48;
  static const int missingReturnConfirmationDays = 5;
  static const int shortNoticeThresholdHours = 24;
  static const int shortNoticeGraceMinutes = 60;

  /// Test parameters only. They are deliberately not labelled as legally
  /// final until the limited lawyer review is complete.
  static const int shortNoticeRemainingBasisPoints = 5000;
  static const int noShowRemainingBasisPoints = 10000;

  static const String documentName = 'ShareItToo Rechtsmappe Privat-Pilot';
  static const String documentVersion = 'V4-2026-08-14';
  static const String language = 'de';

  static const String accountPrivateDeclaration =
      'Ich bin mindestens 18 Jahre alt, handle als natuerliche Person und nutze ShareItToo im Privat-Pilot ausschliesslich privat.';
  static const String listingPrivateDeclaration =
      'Ich biete diesen Gegenstand als Privatperson an, bin zur Vermietung berechtigt und handle weder gewerblich noch beruflich.';
  static const String bookingPrivateDeclaration =
      'Ich buche als Privatperson fuer private Zwecke und akzeptiere, dass ShareItToo keine Kaution, Versicherung oder Schadengarantie anbietet.';

  static const String riskNotice =
      'ShareItToo prueft Gegenstand, Eigentum, Sicherheit, Zeitwert und Versicherungsschutz nicht. ShareItToo bietet keine Kaution, Versicherung oder Schadengarantie. Vermieter und Mieter pruefen ihr Risiko und ihren Versicherungsschutz selbst.';

  /// Technical positive list for the first private pilot. Broad categories
  /// containing vehicles, medical goods, living things or an unrestricted
  /// "other" escape hatch are intentionally excluded fail-closed.
  static const Set<String> allowedCategoryIds = {
    'cat1', // Elektronik
    'cat2', // Computer & IT
    'cat3', // Kameras & Drohnen
    'cat4', // Gaming & VR
    'cat5', // Haushaltsgeraete
    'cat6', // Moebel & Wohnen
    'cat7', // Garten & Heimwerken
    'cat8', // Werkzeuge & Maschinen
    'cat12', // Mode & Accessoires
    'cat14', // Musikinstrumente & DJ
    'cat15', // Buecher, Filme & Medien
    'cat16', // Schmuck & Uhren
    'cat17', // Kunst & Sammlerstuecke
    'cat20', // Bueroausstattung
    'cat22', // Eventausstattung
    'cat23', // Reise- und Campingausstattung
  };

  static bool categoryAllowed(String categoryId) =>
      allowedCategoryIds.contains(categoryId.trim());
}
