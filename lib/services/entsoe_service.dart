import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/price_data.dart';

class EntsoeService {
  static const String _baseUrl = 'https://web-api.tp.entsoe.eu/api';
  // CORS proxy for web platform (ENTSO-E API doesn't support CORS)
  static const String _corsProxy = 'https://corsproxy.io/?';

  final String securityToken;

  EntsoeService({required this.securityToken});

  /// Returns the appropriate URL, with CORS proxy if on web
  String _getUrl(String baseUrl) {
    if (kIsWeb) {
      return '$_corsProxy${Uri.encodeComponent(baseUrl)}';
    }
    return baseUrl;
  }

  Future<EntsoeResponse> getDayAheadPrices(String domain, String date) async {
    if (domain.isEmpty || securityToken.isEmpty) {
      return EntsoeResponse(error: 'Domain or Security Token not configured');
    }

    final apiUrl = '$_baseUrl?securityToken=$securityToken'
        '&documentType=A44'
        '&in_Domain=$domain'
        '&out_Domain=$domain'
        '&periodStart=${date}0000'
        '&periodEnd=${date}2300';

    final url = Uri.parse(_getUrl(apiUrl));

    try {
      final response = await http.get(url).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('ENTSO-E connection timeout'),
          );

      if (response.statusCode != 200) {
        return EntsoeResponse(
          error: 'HTTP Error ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      return _parseXmlResponse(response.body);
    } catch (e) {
      return EntsoeResponse(error: 'Connection error: $e');
    }
  }

  EntsoeResponse _parseXmlResponse(String xmlString) {
    try {
      final document = XmlDocument.parse(xmlString);
      final root = document.rootElement;

      // Check for error response
      if (root.name.local == 'Acknowledgement_MarketDocument') {
        final reasonText = root.findAllElements('text').firstOrNull?.innerText;
        return EntsoeResponse(
          error: reasonText ?? 'Unknown error in ENTSO-E response',
        );
      }

      // Parse successful response
      String? start;
      String? end;
      String? businessType;
      String? priceUnit;
      String? resolution;
      List<double> prices = [];

      // Get period time interval
      final timeInterval = root.findAllElements('period.timeInterval').firstOrNull;
      if (timeInterval != null) {
        start = timeInterval.findElements('start').firstOrNull?.innerText;
        end = timeInterval.findElements('end').firstOrNull?.innerText;
      }

      // Get TimeSeries data
      final timeSeries = root.findAllElements('TimeSeries').firstOrNull;
      if (timeSeries != null) {
        businessType =
            timeSeries.findElements('businessType').firstOrNull?.innerText;
        priceUnit = timeSeries
            .findElements('price_Measure_Unit.name')
            .firstOrNull
            ?.innerText;

        // Get Period and Points
        final period = timeSeries.findAllElements('Period').firstOrNull;
        if (period != null) {
          resolution = period.findElements('resolution').firstOrNull?.innerText;

          // Extract all price points
          final points = period.findAllElements('Point');
          for (final point in points) {
            final priceAmount =
                point.findElements('price.amount').firstOrNull?.innerText;
            if (priceAmount != null) {
              final price = double.tryParse(priceAmount);
              if (price != null) {
                prices.add(price);
              }
            }
          }
        }
      }

      return EntsoeResponse(
        start: start,
        end: end,
        businessType: businessType,
        priceUnit: priceUnit,
        resolution: resolution,
        prices: prices,
      );
    } catch (e) {
      return EntsoeResponse(error: 'XML parsing error: $e');
    }
  }

  /// Gets historical prices for a date range (e.g., last 30 days)
  /// Returns all prices in the period for calculating historical min/max
  Future<HistoricalPriceData> getHistoricalPrices(
    String domain,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (domain.isEmpty || securityToken.isEmpty) {
      return HistoricalPriceData(
        error: 'Domain or Security Token not configured',
      );
    }

    List<double> allPrices = [];
    String? lastError;
    int daysWithData = 0;

    // Fetch data day by day (API has limits on date ranges)
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      final dateStr = formatDateForApi(currentDate);
      final response = await getDayAheadPrices(domain, dateStr);

      if (!response.hasError && response.prices.isNotEmpty) {
        allPrices.addAll(response.prices);
        daysWithData++;
      } else if (response.hasError) {
        lastError = response.error;
      }

      currentDate = currentDate.add(const Duration(days: 1));

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (allPrices.isEmpty) {
      return HistoricalPriceData(
        error: lastError ?? 'No historical data available',
      );
    }

    // Calculate statistics
    allPrices.sort();
    final minPrice = allPrices.first;
    final maxPrice = allPrices.last;
    final avgPrice = allPrices.reduce((a, b) => a + b) / allPrices.length;

    // Calculate standard deviation
    final variance = allPrices
            .map((p) => (p - avgPrice) * (p - avgPrice))
            .reduce((a, b) => a + b) /
        allPrices.length;
    final stdDeviation = variance > 0 ? sqrt(variance) : 0.0;

    return HistoricalPriceData(
      minPrice: minPrice,
      maxPrice: maxPrice,
      avgPrice: avgPrice,
      stdDeviation: stdDeviation,
      totalPrices: allPrices.length,
      daysWithData: daysWithData,
      startDate: startDate,
      endDate: endDate,
    );
  }

  static String formatDateForApi(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

/// Dati storici aggregati per il calcolo delle soglie
class HistoricalPriceData {
  final double minPrice;
  final double maxPrice;
  final double avgPrice;
  final double stdDeviation;
  final int totalPrices;
  final int daysWithData;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? error;

  HistoricalPriceData({
    this.minPrice = 0,
    this.maxPrice = 0,
    this.avgPrice = 0,
    this.stdDeviation = 0,
    this.totalPrices = 0,
    this.daysWithData = 0,
    this.startDate,
    this.endDate,
    this.error,
  });

  bool get hasError => error != null && error!.isNotEmpty;
  bool get hasData => totalPrices > 0;

  /// Percentuale di maturità dei dati (0-100%)
  int get dataMaturityPercent {
    if (startDate == null || endDate == null) return 0;
    final expectedDays = endDate!.difference(startDate!).inDays + 1;
    return ((daysWithData / expectedDays) * 100).round().clamp(0, 100);
  }
}

/// Cache dei prezzi giornalieri per aggiornamento incrementale
/// La cache memorizza sempre 1 anno di dati (365 giorni)
class HistoricalPriceCache {
  static const int cacheStorageDays = 365; // Sempre 1 anno in cache

  final String domain;
  final Map<String, List<double>> dailyPrices; // key: "YYYY-MM-DD", value: 24 prices
  final DateTime lastUpdate;

  HistoricalPriceCache({
    required this.domain,
    required this.dailyPrices,
    required this.lastUpdate,
  });

  /// Converte in JSON per storage
  Map<String, dynamic> toJson() => {
    'domain': domain,
    'dailyPrices': dailyPrices,
    'lastUpdate': lastUpdate.toIso8601String(),
  };

  /// Crea da JSON
  factory HistoricalPriceCache.fromJson(Map<String, dynamic> json) {
    final rawPrices = json['dailyPrices'] as Map<String, dynamic>;
    final dailyPrices = <String, List<double>>{};

    rawPrices.forEach((key, value) {
      dailyPrices[key] = (value as List).map((e) => (e as num).toDouble()).toList();
    });

    return HistoricalPriceCache(
      domain: json['domain'] as String,
      dailyPrices: dailyPrices,
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
    );
  }

  /// Calcola le statistiche aggregate dai dati cached
  /// [periodDays] specifica quanti giorni usare per il calcolo (default: tutti)
  HistoricalPriceData toHistoricalData({int? periodDays}) {
    if (dailyPrices.isEmpty) {
      return HistoricalPriceData(error: 'No data in cache');
    }

    // Filtra i giorni in base al periodo richiesto
    Map<String, List<double>> filteredPrices;
    if (periodDays != null) {
      final cutoffDate = DateTime.now().subtract(Duration(days: periodDays));
      filteredPrices = <String, List<double>>{};
      dailyPrices.forEach((dateKey, prices) {
        final date = DateTime.parse(dateKey);
        if (date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate)) {
          filteredPrices[dateKey] = prices;
        }
      });
    } else {
      filteredPrices = dailyPrices;
    }

    if (filteredPrices.isEmpty) {
      return HistoricalPriceData(error: 'No data in selected period');
    }

    final allPrices = <double>[];
    for (final prices in filteredPrices.values) {
      allPrices.addAll(prices);
    }

    if (allPrices.isEmpty) {
      return HistoricalPriceData(error: 'No prices in cache');
    }

    allPrices.sort();
    final minPrice = allPrices.first;
    final maxPrice = allPrices.last;
    final avgPrice = allPrices.reduce((a, b) => a + b) / allPrices.length;

    // Calcola deviazione standard
    final variance = allPrices
        .map((p) => (p - avgPrice) * (p - avgPrice))
        .reduce((a, b) => a + b) / allPrices.length;
    final stdDeviation = variance > 0 ? sqrt(variance) : 0.0;

    // Trova date dal cache filtrato
    final dates = filteredPrices.keys.toList()..sort();
    final startDate = dates.isNotEmpty ? DateTime.parse(dates.first) : null;
    final endDate = dates.isNotEmpty ? DateTime.parse(dates.last) : null;

    return HistoricalPriceData(
      minPrice: minPrice,
      maxPrice: maxPrice,
      avgPrice: avgPrice,
      stdDeviation: stdDeviation,
      totalPrices: allPrices.length,
      daysWithData: filteredPrices.length,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Verifica se il cache è valido per il dominio corrente
  /// La cache è sempre di 1 anno, quindi non dipende dal periodo selezionato
  bool isValidForDomain(String currentDomain) {
    return domain == currentDomain;
  }

  /// Verifica se il cache è aggiornato (ultimo update è oggi)
  bool get isUpToDate {
    final today = DateTime.now();
    return lastUpdate.year == today.year &&
           lastUpdate.month == today.month &&
           lastUpdate.day == today.day;
  }

  /// Ottiene i giorni mancanti da aggiungere (sempre basato su 1 anno)
  List<DateTime> getMissingDays() {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final targetStart = today.subtract(const Duration(days: cacheStorageDays));

    final missingDays = <DateTime>[];
    var current = targetStart;

    while (current.isBefore(yesterday) || current.isAtSameMomentAs(yesterday)) {
      final dateKey = _formatDate(current);
      if (!dailyPrices.containsKey(dateKey)) {
        missingDays.add(current);
      }
      current = current.add(const Duration(days: 1));
    }

    return missingDays;
  }

  /// Rimuove i giorni troppo vecchi (oltre 1 anno)
  HistoricalPriceCache pruneOldDays() {
    final today = DateTime.now();
    final cutoffDate = today.subtract(const Duration(days: cacheStorageDays));

    final prunedPrices = <String, List<double>>{};
    dailyPrices.forEach((dateKey, prices) {
      final date = DateTime.parse(dateKey);
      if (date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate)) {
        prunedPrices[dateKey] = prices;
      }
    });

    return HistoricalPriceCache(
      domain: domain,
      dailyPrices: prunedPrices,
      lastUpdate: lastUpdate,
    );
  }

  /// Aggiunge nuovi dati giornalieri
  HistoricalPriceCache addDayData(DateTime date, List<double> prices) {
    final newPrices = Map<String, List<double>>.from(dailyPrices);
    newPrices[_formatDate(date)] = prices;

    return HistoricalPriceCache(
      domain: domain,
      dailyPrices: newPrices,
      lastUpdate: DateTime.now(),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Gets a specific percentile value from historical data
  /// [percentile] is a value between 0.0 and 1.0 (e.g., 0.2 for 20th percentile)
  /// [periodDays] filters to specific period (optional)
  double? getPercentile(double percentile, {int? periodDays}) {
    if (dailyPrices.isEmpty || percentile < 0 || percentile > 1) return null;

    // Filter by period if specified
    Map<String, List<double>> filteredPrices;
    if (periodDays != null) {
      final cutoffDate = DateTime.now().subtract(Duration(days: periodDays));
      filteredPrices = <String, List<double>>{};
      dailyPrices.forEach((dateKey, prices) {
        final date = DateTime.parse(dateKey);
        if (date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate)) {
          filteredPrices[dateKey] = prices;
        }
      });
    } else {
      filteredPrices = dailyPrices;
    }

    if (filteredPrices.isEmpty) return null;

    // Collect all prices and sort them
    final allPrices = <double>[];
    for (final prices in filteredPrices.values) {
      allPrices.addAll(prices);
    }

    if (allPrices.isEmpty) return null;

    allPrices.sort();

    // Calculate percentile index using linear interpolation
    final index = percentile * (allPrices.length - 1);
    final lowerIndex = index.floor();
    final upperIndex = index.ceil();

    if (lowerIndex == upperIndex) {
      return allPrices[lowerIndex];
    }

    // Linear interpolation between adjacent values
    final fraction = index - lowerIndex;
    return allPrices[lowerIndex] * (1 - fraction) + allPrices[upperIndex] * fraction;
  }

  /// Gets both low and high percentile thresholds at once
  /// Returns (p_low, p_high) for the quantile algorithm
  (double, double)? getPercentileThresholds(double lowPercentile, double highPercentile, {int? periodDays}) {
    final pLow = getPercentile(lowPercentile, periodDays: periodDays);
    final pHigh = getPercentile(highPercentile, periodDays: periodDays);

    if (pLow == null || pHigh == null) return null;
    return (pLow, pHigh);
  }

  /// Gets daily statistics for the historical chart
  /// Returns a list of [DailyPriceStats] sorted by date
  List<DailyPriceStats> getDailyStats({int? periodDays}) {
    if (dailyPrices.isEmpty) return [];

    // Filtra per periodo se specificato
    Map<String, List<double>> filteredPrices;
    if (periodDays != null) {
      final cutoffDate = DateTime.now().subtract(Duration(days: periodDays));
      filteredPrices = <String, List<double>>{};
      dailyPrices.forEach((dateKey, prices) {
        final date = DateTime.parse(dateKey);
        if (date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate)) {
          filteredPrices[dateKey] = prices;
        }
      });
    } else {
      filteredPrices = dailyPrices;
    }

    final stats = <DailyPriceStats>[];

    filteredPrices.forEach((dateKey, prices) {
      if (prices.isEmpty) return;

      final sortedPrices = List<double>.from(prices)..sort();
      final minPrice = sortedPrices.first;
      final maxPrice = sortedPrices.last;
      final avgPrice = prices.reduce((a, b) => a + b) / prices.length;

      stats.add(DailyPriceStats(
        date: DateTime.parse(dateKey),
        minPrice: minPrice,
        maxPrice: maxPrice,
        avgPrice: avgPrice,
      ));
    });

    // Ordina per data
    stats.sort((a, b) => a.date.compareTo(b.date));

    return stats;
  }

  /// Calcola le statistiche globali per il periodo
  GlobalPriceStats? getGlobalStats({int? periodDays}) {
    final dailyStats = getDailyStats(periodDays: periodDays);
    if (dailyStats.isEmpty) return null;

    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;
    double totalAvg = 0;

    for (final day in dailyStats) {
      if (day.minPrice < globalMin) globalMin = day.minPrice;
      if (day.maxPrice > globalMax) globalMax = day.maxPrice;
      totalAvg += day.avgPrice;
    }

    return GlobalPriceStats(
      minPrice: globalMin,
      maxPrice: globalMax,
      avgPrice: totalAvg / dailyStats.length,
    );
  }
}

/// Statistiche giornaliere per il grafico
class DailyPriceStats {
  final DateTime date;
  final double minPrice;
  final double maxPrice;
  final double avgPrice;

  DailyPriceStats({
    required this.date,
    required this.minPrice,
    required this.maxPrice,
    required this.avgPrice,
  });
}

/// Statistiche globali del periodo
class GlobalPriceStats {
  final double minPrice;
  final double maxPrice;
  final double avgPrice;

  GlobalPriceStats({
    required this.minPrice,
    required this.maxPrice,
    required this.avgPrice,
  });
}
