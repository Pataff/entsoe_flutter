import 'dart:convert';
import 'dart:io';
import '../models/price_data.dart';

class TcpService {
  Socket? _socket;
  bool _isConnected = false;
  String? _lastResponse;

  bool get isConnected => _isConnected;
  String? get lastResponse => _lastResponse;

  Future<TcpResult> connect(String host, int port) async {
    try {
      await disconnect();
      _socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));
      _isConnected = true;
      return TcpResult.success();
    } catch (e) {
      _isConnected = false;
      return TcpResult.error('Errore connessione TCP: $e');
    }
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      try {
        await _socket!.close();
      } catch (_) {}
      _socket = null;
    }
    _isConnected = false;
  }

  /// Invia il comando Impr (Energy reduction) al server dView
  /// Formato: {"impr":"all","heat":XX,"fan":XX}\n
  /// dove XX è la percentuale di potenza (heat e fan hanno lo stesso valore)
  Future<TcpResult> sendImprCommand(
    String host,
    int port,
    int powerPercentage,
  ) async {
    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));

      // Comando Impr secondo protocollo MES interface
      final command = {
        'impr': 'all',
        'heat': powerPercentage,
        'fan': powerPercentage,
      };

      final jsonString = jsonEncode(command);
      // NDJSON: ogni messaggio deve terminare con \n
      socket.write('$jsonString\n');
      await socket.flush();

      // Attendi risposta dal server
      String response = '';
      try {
        socket.timeout(const Duration(seconds: 5));
        await for (var data in socket) {
          response += utf8.decode(data);
          if (response.contains('\n')) break;
        }
      } catch (_) {
        // Timeout o errore lettura - non critico
      }

      _lastResponse = response.isNotEmpty ? response.trim() : null;
      await socket.close();

      return TcpResult.success(response: _lastResponse);
    } catch (e) {
      return TcpResult.error('Errore invio comando Impr: $e');
    }
  }

  /// Invia il comando Impr basato sui dati dell'ora corrente
  Future<TcpResult> sendCurrentHourImpr(
    String host,
    int port,
    DayPriceData? todayData,
  ) async {
    if (todayData == null) {
      return TcpResult.error('Nessun dato disponibile per oggi');
    }

    final now = DateTime.now();
    final currentHour = now.hour;

    if (currentHour >= todayData.hourlyPrices.length) {
      return TcpResult.error('Dati ora corrente non disponibili');
    }

    final currentPrice = todayData.hourlyPrices[currentHour];
    final powerPercentage = currentPrice.powerPercentage;

    return sendImprCommand(host, port, powerPercentage);
  }

  /// Invia tutti i dati dei prezzi (metodo legacy)
  Future<TcpResult> sendPriceData(
    String host,
    int port,
    DayPriceData dayData,
  ) async {
    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));

      final jsonData = _buildJsonPayload(dayData);
      socket.write('$jsonData\n');
      await socket.flush();
      await socket.close();

      return TcpResult.success();
    } catch (e) {
      return TcpResult.error('Errore invio dati TCP: $e');
    }
  }

  Future<TcpResult> sendAllDaysData(
    String host,
    int port, {
    DayPriceData? yesterday,
    DayPriceData? today,
    DayPriceData? tomorrow,
  }) async {
    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));

      final payload = {
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'energy_prices',
        'data': {
          if (yesterday != null) 'yesterday': yesterday.toJson(),
          if (today != null) 'today': today.toJson(),
          if (tomorrow != null) 'tomorrow': tomorrow.toJson(),
        },
        'currentHour': _getCurrentHourData(today),
      };

      final jsonString = jsonEncode(payload);
      socket.write('$jsonString\n');
      await socket.flush();
      await socket.close();

      return TcpResult.success();
    } catch (e) {
      return TcpResult.error('Errore invio dati TCP: $e');
    }
  }

  Map<String, dynamic>? _getCurrentHourData(DayPriceData? today) {
    if (today == null) return null;

    final now = DateTime.now();
    final currentHour = now.hour;

    if (currentHour < today.hourlyPrices.length) {
      final currentPrice = today.hourlyPrices[currentHour];
      return {
        'hour': currentHour,
        'price': currentPrice.price,
        'percentage': currentPrice.percentage,
        'powerBand': currentPrice.powerBand,
        'powerPercentage': currentPrice.powerPercentage,
        'powerBandLabel': currentPrice.powerBandLabel,
      };
    }
    return null;
  }

  String _buildJsonPayload(DayPriceData dayData) {
    return jsonEncode(dayData.toJson());
  }
}

class TcpResult {
  final bool success;
  final String? error;
  final String? response;

  TcpResult._({required this.success, this.error, this.response});

  factory TcpResult.success({String? response}) =>
      TcpResult._(success: true, response: response);
  factory TcpResult.error(String message) =>
      TcpResult._(success: false, error: message);
}
