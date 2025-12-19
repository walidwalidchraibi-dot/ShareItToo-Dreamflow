import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { de, en }

class LocalizationController extends ChangeNotifier {
  static const _prefsKey = 'app_language_code';
  AppLanguage _language = AppLanguage.de;

  AppLanguage get language => _language;
  String get code => _language == AppLanguage.de ? 'de' : 'en';

  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code == 'en') {
        _language = AppLanguage.en;
        notifyListeners();
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {
      // ignore
    }
  }

  String t(String key) {
    final table = _language == AppLanguage.de ? _de : _en;
    return table[key] ?? key;
  }

  static const Map<String, String> _de = {
    // Navigation
    'Erkunden': 'Erkunden',
    'Wunschlisten': 'Wunschlisten',
    'Buchungen': 'Buchungen',
    'Nachrichten': 'Nachrichten',
    'Profil': 'Profil',

    // Common actions/labels
    'Alle ansehen': 'Alle ansehen',
    'Alle Kategorien': 'Alle Kategorien',
    'Sprache': 'Sprache',
    'Deutsch': 'Deutsch',
    'English': 'English',
    'Abbrechen': 'Abbrechen',
    'Bald verfügbar': 'Bald verfügbar',
    'Nicht verfügbar': 'Nicht verfügbar',
    'Jetzt suchen': 'Jetzt suchen',
    'Zurücksetzen': 'Zurücksetzen',
    'Anwenden': 'Anwenden',

    // Explore
    'Willkommen 👋': 'Willkommen 👋',
    'Sieh dir Details zu deiner letzten Miete an': 'Sieh dir Details zu deiner letzten Miete an',
    'Am meisten gebucht': 'Am meisten gebucht',
    'Neue Angebote': 'Neue Angebote',
    'Kunden gefällt auch …': 'Kunden gefällt auch …',
    'Kunden gefällt auch': 'Kunden gefällt auch',
    'Kunden teilen auch gerne': 'Kunden teilen auch gerne',
    'Gefiltert nach:': 'Gefiltert nach:',
    'Nicht verifiziert': 'Nicht verifiziert',
    'Verifiziert': 'Verifiziert',
    'Eingestellt am': 'Eingestellt am',
    '€/Tag': '€/Tag',

    // Listing details
    'Verfügbarkeit prüfen': 'Verfügbarkeit prüfen',
    'Reservieren': 'Reservieren',
    'Anfragen': 'Anfragen',
    'Anfrage gesendet (Demo)': 'Anfrage gesendet (Demo)',
    'Zum Profil': 'Zum Profil',
    'Profil des Anbieters': 'Profil des Anbieters',
    'Öffentliches Profil und Bewertungen (Demoseite).': 'Öffentliches Profil und Bewertungen (Demoseite).',
    'Anbieter': 'Anbieter',
    'Laden …': 'Laden …',
    'Verliehen': 'Verliehen',

    // Category labels (used as keys)
    'Elektronik': 'Elektronik',
    'Kameras & Drohnen': 'Kameras & Drohnen',
    'Werkzeuge': 'Werkzeuge',
    'Fahrzeuge': 'Fahrzeuge',
    'Freizeit & Sport': 'Freizeit & Sport',
    'Outdoor & Camping': 'Outdoor & Camping',
    'Möbel & Zuhause': 'Möbel & Zuhause',
    'Haushaltsgeräte': 'Haushaltsgeräte',
    'Garten': 'Garten',
    'Instrumente': 'Instrumente',
    'Party & Events': 'Party & Events',
    'Bücher & Medien': 'Bücher & Medien',
    'Büro/IT': 'Büro/IT',
    'Gaming': 'Gaming',
    'Baby & Kinder': 'Baby & Kinder',
    'Mode & Accessoires': 'Mode & Accessoires',

    // Filters
    'Filter': 'Filter',
    'Ort': 'Ort',
    'Preis pro Tag': 'Preis pro Tag',
    'Entfernung (bis zu)': 'Entfernung (bis zu)',
    'aufsteigend': 'aufsteigend',
    'absteigend': 'absteigend',
    'Verifizierung': 'Verifizierung',
    'Nur verifiziert': 'Nur verifiziert',
    'Zustand': 'Zustand',
    'Neu': 'Neu',
    'Gebraucht': 'Gebraucht',
    'Egal': 'Egal',
    'Entfernung': 'Entfernung',
    'Kategorien': 'Kategorien',
    'Verfügbarkeit (optional)': 'Verfügbarkeit (optional)',
    'Zeitraum wählen': 'Zeitraum wählen',
    'Sortieren nach': 'Sortieren nach',
    'Preis': 'Preis',
    'Bewertung': 'Bewertung',
    'Neueste': 'Neueste',

    // Profile
    'Benachrichtigungen': 'Benachrichtigungen',
    'Hier siehst du künftig deine Benachrichtigungen.': 'Hier siehst du künftig deine Benachrichtigungen.',
    'Mein Profil anzeigen': 'Mein Profil anzeigen',
    'Bewertungen': 'Bewertungen',
    'Ø Bewertung': 'Ø Bewertung',
    'Dabei seit': 'Dabei seit',

    'Vergangene Buchungen': 'Vergangene Buchungen',
    'Kontakte': 'Kontakte',
    'Kontoeinstellungen': 'Kontoeinstellungen',
    'Hilfe-Center': 'Hilfe-Center',
    'Rechtliches': 'Rechtliches',
    'Abmelden': 'Abmelden',
    'Abmelden?': 'Abmelden?',
    'Du kannst dich jederzeit wieder anmelden.': 'Du kannst dich jederzeit wieder anmelden.',
    'Abgemeldet (Demo)': 'Abgemeldet (Demo)',
    'Hier erscheinen deine abgeschlossenen Buchungen.': 'Hier erscheinen deine abgeschlossenen Buchungen.',
    'Verwalte deine Kontakte und Vermieter.': 'Verwalte deine Kontakte und Vermieter.',
    'Profil, Sicherheit und Benachrichtigungen.': 'Profil, Sicherheit und Benachrichtigungen.',
    'FAQ und Support.': 'FAQ und Support.',
    'AGB, Datenschutz und Impressum.': 'AGB, Datenschutz und Impressum.',

    // Own Profile
    'Mein Profil': 'Mein Profil',
    'Profil-Link kopiert': 'Profil-Link kopiert',
    'Anzeigen': 'Anzeigen',
    'Interessen': 'Interessen',
    'Über mich': 'Über mich',
    'Keine Anzeigen': 'Keine Anzeigen',
    'pro Tag': 'pro Tag',
    'Aktiv': 'Aktiv',
    'Keine Historie': 'Keine Historie',
    'Abgeschlossen': 'Abgeschlossen',
    'Nutzer': 'Nutzer',
    'Sehr freundliche Kommunikation und schnelle Abwicklung.': 'Sehr freundliche Kommunikation und schnelle Abwicklung.',
    'Kurzbeschreibung': 'Kurzbeschreibung',
    'Erzähle etwas über dich…': 'Erzähle etwas über dich…',
    'Speichern': 'Speichern',
    'Vertrauen & Leistung': 'Vertrauen & Leistung',
    'Reaktionszeit (90T)': 'Reaktionszeit (90T)',
    'Storno-Rate (90T)': 'Storno-Rate (90T)',
    'Trust Meter': 'Trust Meter',

    // New
    'Meine Anzeigen': 'Meine Anzeigen',
    'Laufend': 'Laufend',
    'für später gespeichert': 'für später gespeichert',
    'Akzeptieren': 'Akzeptieren',
    'Ablehnen': 'Ablehnen',
    'Anfrage': 'Anfrage',
    'Zeitraum': 'Zeitraum',
    'Language': 'Sprache',
    'Noch keine gespeicherten Elemente': 'Noch keine gespeicherten Elemente',
    'Noch keine Bewertungen': 'Noch keine Bewertungen',
    'Noch keine Bewertungen vorhanden.': 'Noch keine Bewertungen vorhanden.',
    'Zur Wunschliste hinzugefügt': 'Zur Wunschliste hinzugefügt',

    // Actions on details sheet
    'Anzeige ansehen': 'Anzeige ansehen',
    'Zu Wunschlisten hinzufügen': 'Zu Wunschlisten hinzufügen',

    // Monetize teaser
    'you want to make money with any item you posess?': 'Willst du mit jedem Gegenstand, den du besitzt, Geld verdienen?',
    'Neue Anzeige erstellen': 'Neue Anzeige erstellen',
    'Starte eine neue Anzeige in wenigen Schritten.': 'Starte eine neue Anzeige in wenigen Schritten.',
    'Erstelle eine neue Anzeige': 'Erstelle eine neue Anzeige',
  };

  static const Map<String, String> _en = {
    // Navigation
    'Erkunden': 'Explore',
    'Wunschlisten': 'Wishlists',
    'Buchungen': 'Bookings',
    'Nachrichten': 'Messages',
    'Profil': 'Profile',

    // Common actions/labels
    'Alle ansehen': 'See all',
    'Alle Kategorien': 'All categories',
    'Sprache': 'Language',
    'Deutsch': 'German',
    'English': 'English',
    'Abbrechen': 'Cancel',
    'Bald verfügbar': 'Coming soon',
    'Nicht verfügbar': 'Unavailable',
    'Jetzt suchen': 'Search now',
    'Zurücksetzen': 'Reset',
    'Anwenden': 'Apply',

    // Explore
    'Willkommen 👋': 'Welcome 👋',
    'Sieh dir Details zu deiner letzten Miete an': 'See details of your last rental',
    'Am meisten gebucht': 'Most booked',
    'Neue Angebote': 'New listings',
    'Kunden gefällt auch …': 'Customers also like …',
    'Kunden gefällt auch': 'Customers also like',
    'Kunden teilen auch gerne': 'Customers also love to share',
    'Gefiltert nach:': 'Filtered by:',
    'Nicht verifiziert': 'Not verified',
    'Verifiziert': 'Verified',
    'Eingestellt am': 'Listed on',
    '€/Tag': '€/day',

    // Listing details
    'Verfügbarkeit prüfen': 'Check availability',
    'Reservieren': 'Reserve',
    'Anfragen': 'Request',
    'Anfrage gesendet (Demo)': 'Request sent (demo)',
    'Zum Profil': 'View profile',
    'Profil des Anbieters': 'Owner profile',
    'Öffentliches Profil und Bewertungen (Demoseite).': 'Public profile and reviews (demo).',
    'Anbieter': 'Owner',
    'Laden …': 'Loading …',
    'Verliehen': 'Times lent',

    // Category labels (keys are DE)
    'Elektronik': 'Electronics',
    'Kameras & Drohnen': 'Cameras & drones',
    'Werkzeuge': 'Tools',
    'Fahrzeuge': 'Vehicles',
    'Freizeit & Sport': 'Leisure & sports',
    'Outdoor & Camping': 'Outdoor & camping',
    'Möbel & Zuhause': 'Furniture & home',
    'Haushaltsgeräte': 'Appliances',
    'Garten': 'Garden',
    'Instrumente': 'Instruments',
    'Party & Events': 'Party & events',
    'Bücher & Medien': 'Books & media',
    'Büro/IT': 'Office/IT',
    'Gaming': 'Gaming',
    'Baby & Kinder': 'Baby & kids',
    'Mode & Accessoires': 'Fashion & accessories',

    // Filters
    'Filter': 'Filters',
    'Ort': 'Location',
    'Preis pro Tag': 'Price per day',
    'Entfernung (bis zu)': 'Distance (up to)',
    'aufsteigend': 'ascending',
    'absteigend': 'descending',
    'Verifizierung': 'Verification',
    'Nur verifiziert': 'Verified only',
    'Zustand': 'Condition',
    'Neu': 'New',
    'Gebraucht': 'Used',
    'Egal': 'Any',
    'Entfernung': 'Distance',
    'Kategorien': 'Categories',
    'Verfügbarkeit (optional)': 'Availability (optional)',
    'Zeitraum wählen': 'Choose date range',
    'Sortieren nach': 'Sort by',
    'Preis': 'Price',
    'Bewertung': 'Rating',
    'Neueste': 'Newest',

    // Profile
    'Benachrichtigungen': 'Notifications',
    'Hier siehst du künftig deine Benachrichtigungen.': 'You will see your notifications here.',
    'Mein Profil anzeigen': 'View my profile',
    'Bewertungen': 'Reviews',
    'Ø Bewertung': 'Avg rating',
    'Dabei seit': 'Member since',

    'Vergangene Buchungen': 'Past bookings',
    'Kontakte': 'Contacts',
    'Kontoeinstellungen': 'Account settings',
    'Hilfe-Center': 'Help Center',
    'Rechtliches': 'Legal',
    'Abmelden': 'Log out',
    'Abmelden?': 'Log out?',
    'Du kannst dich jederzeit wieder anmelden.': 'You can sign in again any time.',
    'Abgemeldet (Demo)': 'Logged out (demo)',
    'Hier erscheinen deine abgeschlossenen Buchungen.': 'Your completed bookings will appear here.',
    'Verwalte deine Kontakte und Vermieter.': 'Manage your contacts and hosts.',
    'Profil, Sicherheit und Benachrichtigungen.': 'Profile, security and notifications.',
    'FAQ und Support.': 'FAQ and support.',
    'AGB, Datenschutz und Impressum.': 'Terms, privacy and imprint.',

    // Own Profile
    'Mein Profil': 'My profile',
    'Profil-Link kopiert': 'Profile link copied',
    'Anzeigen': 'Listings',
    'Interessen': 'Interests',
    'Über mich': 'About me',
    'Keine Anzeigen': 'No listings',
    'pro Tag': 'per day',
    'Aktiv': 'Active',
    'Keine Historie': 'No history',
    'Abgeschlossen': 'Completed',
    'Nutzer': 'User',
    'Sehr freundliche Kommunikation und schnelle Abwicklung.': 'Very friendly communication and quick processing.',
    'Kurzbeschreibung': 'Short bio',
    'Erzähle etwas über dich…': 'Tell something about yourself…',
    'Speichern': 'Save',
    'Vertrauen & Leistung': 'Trust & Performance',
    'Reaktionszeit (90T)': 'Response time (90d)',
    'Storno-Rate (90T)': 'Cancellation rate (90d)',
    'Trust Meter': 'Trust Meter',

    // New
    'Meine Anzeigen': 'My listings',
    'Laufend': 'Ongoing',
    'für später gespeichert': 'Saved for later',
    'Akzeptieren': 'Accept',
    'Ablehnen': 'Decline',
    'Anfrage': 'Request',
    'Zeitraum': 'Dates',
    'Language': 'Language',
    'Noch keine gespeicherten Elemente': 'No saved items yet',
    'Noch keine Bewertungen': 'No reviews yet',
    'Noch keine Bewertungen vorhanden.': 'No reviews yet.',
    'Zur Wunschliste hinzugefügt': 'Added to wishlist',

    // Actions on details sheet
    'Anzeige ansehen': 'View listing',
    'Zu Wunschlisten hinzufügen': 'Add to wishlist',

    // Monetize teaser
    'you want to make money with any item you posess?': 'Do you want to make money with any item you possess?',
    'Neue Anzeige erstellen': 'Create a new listing',
    'Starte eine neue Anzeige in wenigen Schritten.': 'Start a new listing in a few steps.',
    'Erstelle eine neue Anzeige': 'Create a new listing',
  };
}

