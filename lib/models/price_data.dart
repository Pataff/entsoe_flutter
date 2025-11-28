class HourlyPrice {
  final DateTime dateTime;
  final double price;
  final double percentage; // Normalized position in the quantile range (0-100%)
  final int _powerPercentage; // Calculated setpoint percentage (continuous value)

  HourlyPrice({
    required this.dateTime,
    required this.price,
    required this.percentage,
    required int powerPercentage,
  }) : _powerPercentage = powerPercentage;

  /// Power band derived from setpoint percentage
  /// Band 3 (green): >= 80% power (low cost)
  /// Band 2 (orange): 40-79% power (medium cost)
  /// Band 1 (red): < 40% power (high cost)
  int get powerBand {
    if (_powerPercentage >= 80) return 3;
    if (_powerPercentage >= 40) return 2;
    return 1;
  }

  String get powerBandLabel {
    switch (powerBand) {
      case 3:
        return 'Low cost ($_powerPercentage%)';
      case 2:
        return 'Medium cost ($_powerPercentage%)';
      case 1:
        return 'High cost ($_powerPercentage%)';
      default:
        return 'N/A';
    }
  }

  /// The actual calculated power setpoint percentage (continuous value 0-100)
  int get powerPercentage => _powerPercentage;

  Map<String, dynamic> toJson() => {
        'dateTime': dateTime.toIso8601String(),
        'price': price,
        'percentage': percentage,
        'powerBand': powerBand,
        'powerPercentage': powerPercentage,
      };
}

class DayPriceData {
  final DateTime date;
  final List<HourlyPrice> hourlyPrices;
  final double minPrice;
  final double maxPrice;
  final double avgPrice;
  final double stdDeviation;

  DayPriceData({
    required this.date,
    required this.hourlyPrices,
    required this.minPrice,
    required this.maxPrice,
    required this.avgPrice,
    required this.stdDeviation,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'avgPrice': avgPrice,
        'stdDeviation': stdDeviation,
        'hourlyPrices': hourlyPrices.map((h) => h.toJson()).toList(),
      };
}

class EntsoeResponse {
  final String? start;
  final String? end;
  final String? businessType;
  final String? priceUnit;
  final String? resolution;
  final String? error;
  final List<double> prices;

  EntsoeResponse({
    this.start,
    this.end,
    this.businessType,
    this.priceUnit,
    this.resolution,
    this.error,
    this.prices = const [],
  });

  bool get hasError => error != null && error!.isNotEmpty;
}
