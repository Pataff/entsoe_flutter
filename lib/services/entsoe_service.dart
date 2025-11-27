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

  static String formatDateForApi(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
