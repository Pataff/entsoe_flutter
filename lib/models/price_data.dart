class HourlyPrice {
  final DateTime dateTime;
  final double price;
  final double percentage;
  final int powerBand; // 1 = Alto (20%), 2 = Medio (50%), 3 = Basso (100%)

  HourlyPrice({
    required this.dateTime,
    required this.price,
    required this.percentage,
    required this.powerBand,
  });

  String get powerBandLabel {
    switch (powerBand) {
      case 3:
        return 'Basso (100%)';
      case 2:
        return 'Medio (50%)';
      case 1:
        return 'Alto (20%)';
      default:
        return 'N/A';
    }
  }

  int get powerPercentage {
    switch (powerBand) {
      case 3:
        return 100;
      case 2:
        return 50;
      case 1:
        return 20;
      default:
        return 0;
    }
  }

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
