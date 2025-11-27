import 'dart:math' show sqrt;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/price_data.dart';

class EntsoeService {
  static const String _baseUrl = 'https://web-api.tp.entsoe.eu/api';

  final String securityToken;

  EntsoeService({required this.securityToken});

  Future<EntsoeResponse> getDayAheadPrices(String domain, String date) async {
    if (domain.isEmpty || securityToken.isEmpty) {
      return EntsoeResponse(error: 'Domain o Security Token non configurati');
    }

    final url = Uri.parse(
      '$_baseUrl?securityToken=$securityToken'
      '&documentType=A44'
      '&in_Domain=$domain'
      '&out_Domain=$domain'
      '&periodStart=${date}0000'
      '&periodEnd=${date}2300',
    );

    try {
      final response = await http.get(url).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Timeout connessione ENTSO-E'),
          );

      if (response.statusCode != 200) {
        return EntsoeResponse(
          error: 'Errore HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      return _parseXmlResponse(response.body);
    } catch (e) {
      return EntsoeResponse(error: 'Errore di connessione: $e');
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
          error: reasonText ?? 'Errore sconosciuto nella risposta ENTSO-E',
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
      return EntsoeResponse(error: 'Errore parsing XML: $e');
    }
  }

  /// Ottiene i prezzi storici per un range di date (es. ultimi 30 giorni)
  /// Restituisce tutti i prezzi nel periodo per calcolare min/max storici
  Future<HistoricalPriceData> getHistoricalPrices(
    String domain,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (domain.isEmpty || securityToken.isEmpty) {
      return HistoricalPriceData(
        error: 'Domain o Security Token non configurati',
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
        error: lastError ?? 'Nessun dato storico disponibile',
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
class HistoricalPriceCache {
  final String domain;
  final int periodDays;
  final Map<String, List<double>> dailyPrices; // key: "YYYY-MM-DD", value: 24 prices
  final DateTime lastUpdate;

  HistoricalPriceCache({
    required this.domain,
    required this.periodDays,
    required this.dailyPrices,
    required this.lastUpdate,
  });

  /// Converte in JSON per storage
  Map<String, dynamic> toJson() => {
    'domain': domain,
    'periodDays': periodDays,
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
      periodDays: json['periodDays'] as int,
      dailyPrices: dailyPrices,
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
    );
  }

  /// Calcola le statistiche aggregate dai dati cached
  HistoricalPriceData toHistoricalData() {
    if (dailyPrices.isEmpty) {
      return HistoricalPriceData(error: 'Nessun dato in cache');
    }

    final allPrices = <double>[];
    for (final prices in dailyPrices.values) {
      allPrices.addAll(prices);
    }

    if (allPrices.isEmpty) {
      return HistoricalPriceData(error: 'Nessun prezzo in cache');
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

    // Trova date dal cache
    final dates = dailyPrices.keys.toList()..sort();
    final startDate = dates.isNotEmpty ? DateTime.parse(dates.first) : null;
    final endDate = dates.isNotEmpty ? DateTime.parse(dates.last) : null;

    return HistoricalPriceData(
      minPrice: minPrice,
      maxPrice: maxPrice,
      avgPrice: avgPrice,
      stdDeviation: stdDeviation,
      totalPrices: allPrices.length,
      daysWithData: dailyPrices.length,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Verifica se il cache è valido per il dominio e periodo correnti
  bool isValidFor(String currentDomain, int currentPeriodDays) {
    return domain == currentDomain && periodDays == currentPeriodDays;
  }

  /// Verifica se il cache è aggiornato (ultimo update è oggi)
  bool get isUpToDate {
    final today = DateTime.now();
    return lastUpdate.year == today.year &&
           lastUpdate.month == today.month &&
           lastUpdate.day == today.day;
  }

  /// Ottiene i giorni mancanti da aggiungere
  List<DateTime> getMissingDays(int targetPeriodDays) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final targetStart = today.subtract(Duration(days: targetPeriodDays));

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

  /// Rimuove i giorni troppo vecchi rispetto al periodo target
  HistoricalPriceCache pruneOldDays(int targetPeriodDays) {
    final today = DateTime.now();
    final cutoffDate = today.subtract(Duration(days: targetPeriodDays));

    final prunedPrices = <String, List<double>>{};
    dailyPrices.forEach((dateKey, prices) {
      final date = DateTime.parse(dateKey);
      if (date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate)) {
        prunedPrices[dateKey] = prices;
      }
    });

    return HistoricalPriceCache(
      domain: domain,
      periodDays: targetPeriodDays,
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
      periodDays: periodDays,
      dailyPrices: newPrices,
      lastUpdate: DateTime.now(),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
