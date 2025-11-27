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
