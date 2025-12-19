import 'dart:math';

/// AI-based price calculator using heuristics (category, condition, location)
class AIPriceCalculatorService {
  /// Strategy toggle: 'quick' (lower prices, faster bookings) or 'premium' (higher prices, max profit)
  static PriceSuggestion calculate({
    required String title,
    required String categoryId,
    required String condition,
    required String address,
    String strategy = 'quick', // 'quick' | 'premium'
  }) {
    // Base price heuristics by category (rough averages in €/day)
    final basePricePerDay = _basePriceForCategory(categoryId);
    
    // Adjust by condition
    final conditionMultiplier = _conditionMultiplier(condition);
    
    // Adjust by location (city vs. rural)
    final locationMultiplier = _locationMultiplier(address);
    
    // Strategy multiplier
    final strategyMultiplier = strategy == 'premium' ? 1.25 : 0.85;
    
    // Calculate adjusted base price
    final adjustedBase = basePricePerDay * conditionMultiplier * locationMultiplier * strategyMultiplier;
    
    // Generate range (±20%)
    final dailyMin = max(1.0, (adjustedBase * 0.8).roundToDouble());
    final dailyMax = (adjustedBase * 1.2).roundToDouble();
    
    // Weekly price: typically ~6.5 days worth (discount for week-long rental)
    final weeklyMin = (dailyMin * 6.5).roundToDouble();
    final weeklyMax = (dailyMax * 6.5).roundToDouble();
    
    // Reasoning
    final reasoning = _buildReasoning(categoryId, condition, address, strategy);
    
    // Optimization tip
    final optimizationTip = strategy == 'premium'
        ? 'Höhere Preise können zu selteneren Buchungen führen. Erwäge die "Schnell vermieten"-Strategie für mehr Auslastung.'
        : 'Niedrigere Preise erhöhen oft die Buchungsrate. Lieber häufiger vermietet als selten teuer.';
    
    return PriceSuggestion(
      dailyPriceMin: dailyMin,
      dailyPriceMax: dailyMax,
      weeklyPriceMin: weeklyMin,
      weeklyPriceMax: weeklyMax,
      reasoning: reasoning,
      optimizationTip: optimizationTip,
    );
  }
  
  static double _basePriceForCategory(String categoryId) {
    // Rough heuristics based on typical rental categories
    final catLower = categoryId.toLowerCase();
    if (catLower.contains('elektronik') || catLower.contains('kamera') || catLower.contains('drohne')) {
      return 15.0;
    } else if (catLower.contains('werkzeug') || catLower.contains('bohrer') || catLower.contains('säge')) {
      return 8.0;
    } else if (catLower.contains('transport') || catLower.contains('anhänger') || catLower.contains('fahrrad')) {
      return 12.0;
    } else if (catLower.contains('sport') || catLower.contains('ski') || catLower.contains('surfbrett')) {
      return 10.0;
    } else if (catLower.contains('möbel') || catLower.contains('tisch') || catLower.contains('stuhl')) {
      return 5.0;
    } else if (catLower.contains('party') || catLower.contains('event') || catLower.contains('zelt')) {
      return 7.0;
    } else if (catLower.contains('outdoor') || catLower.contains('camping') || catLower.contains('grill')) {
      return 6.0;
    } else if (catLower.contains('mode') || catLower.contains('kleidung') || catLower.contains('anzug')) {
      return 9.0;
    } else if (catLower.contains('haushalt') || catLower.contains('küche') || catLower.contains('mixer')) {
      return 4.0;
    } else if (catLower.contains('garten') || catLower.contains('rasenmäher') || catLower.contains('heckenschere')) {
      return 8.0;
    } else {
      // Default fallback
      return 7.0;
    }
  }
  
  static double _conditionMultiplier(String condition) {
    switch (condition) {
      case 'new':
        return 1.3;
      case 'like-new':
        return 1.15;
      case 'good':
        return 1.0;
      case 'acceptable':
        return 0.75;
      default:
        return 1.0;
    }
  }
  
  static double _locationMultiplier(String address) {
    // Simple heuristic: detect major German cities
    final addrLower = address.toLowerCase();
    final majorCities = ['berlin', 'münchen', 'hamburg', 'köln', 'frankfurt', 'stuttgart', 'düsseldorf', 'leipzig', 'dortmund'];
    for (final city in majorCities) {
      if (addrLower.contains(city)) {
        return 1.2; // Higher demand in cities
      }
    }
    return 1.0; // Rural/smaller towns
  }
  
  static String _buildReasoning(String categoryId, String condition, String address, String strategy) {
    final catLabel = _categoryLabel(categoryId);
    final condLabel = _conditionLabel(condition);
    final locLabel = _locationLabel(address);
    final stratLabel = strategy == 'premium' ? 'Maximaler Gewinn' : 'Schnell vermieten';
    
    return 'Basierend auf $catLabel in Zustand "$condLabel" für $locLabel. Strategie: $stratLabel.';
  }
  
  static String _categoryLabel(String categoryId) {
    final catLower = categoryId.toLowerCase();
    if (catLower.contains('elektronik')) return 'Elektronik';
    if (catLower.contains('werkzeug')) return 'Werkzeuge';
    if (catLower.contains('transport')) return 'Transport';
    if (catLower.contains('sport')) return 'Sport';
    if (catLower.contains('möbel')) return 'Möbel';
    if (catLower.contains('party')) return 'Party & Event';
    if (catLower.contains('outdoor')) return 'Outdoor';
    if (catLower.contains('mode')) return 'Mode';
    if (catLower.contains('haushalt')) return 'Haushalt';
    if (catLower.contains('garten')) return 'Garten';
    return 'diese Kategorie';
  }
  
  static String _conditionLabel(String condition) {
    switch (condition) {
      case 'new':
        return 'Neu';
      case 'like-new':
        return 'Wie Neu';
      case 'good':
        return 'Gut';
      case 'acceptable':
        return 'Akzeptabel';
      default:
        return condition;
    }
  }
  
  static String _locationLabel(String address) {
    final addrLower = address.toLowerCase();
    final majorCities = ['berlin', 'münchen', 'hamburg', 'köln', 'frankfurt', 'stuttgart', 'düsseldorf', 'leipzig', 'dortmund'];
    for (final city in majorCities) {
      if (addrLower.contains(city)) {
        return city[0].toUpperCase() + city.substring(1);
      }
    }
    return 'diese Region';
  }
}

class PriceSuggestion {
  final double dailyPriceMin;
  final double dailyPriceMax;
  final double weeklyPriceMin;
  final double weeklyPriceMax;
  final String reasoning;
  final String optimizationTip;
  
  const PriceSuggestion({
    required this.dailyPriceMin,
    required this.dailyPriceMax,
    required this.weeklyPriceMin,
    required this.weeklyPriceMax,
    required this.reasoning,
    required this.optimizationTip,
  });
}
