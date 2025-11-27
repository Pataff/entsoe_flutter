import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/price_data.dart';
import '../models/connection_status.dart';
import '../services/entsoe_service.dart';
import '../services/price_calculator.dart';
import '../services/tcp_service.dart';
import '../services/storage_service.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final TcpService _tcpService = TcpService();

  AppSettings _settings = AppSettings();
  ConnectionStatus _connectionStatus = ConnectionStatus();
  DayPriceData? _yesterdayData;
  DayPriceData? _todayData;
  DayPriceData? _tomorrowData;
  HistoricalPriceData? _historicalData;
  bool _isLoading = false;
  bool _isLoadingHistorical = false;
  String? _lastError;
  Timer? _refreshTimer;
  Timer? _tcpSendTimer;

  // Getters
  AppSettings get settings => _settings;
  ConnectionStatus get connectionStatus => _connectionStatus;
  DayPriceData? get yesterdayData => _yesterdayData;
  DayPriceData? get todayData => _todayData;
  DayPriceData? get tomorrowData => _tomorrowData;
  HistoricalPriceData? get historicalData => _historicalData;
  bool get isLoading => _isLoading;
  bool get isLoadingHistorical => _isLoadingHistorical;
  String? get lastError => _lastError;
  bool get hasData =>
      _yesterdayData != null || _todayData != null || _tomorrowData != null;
  bool get hasHistoricalData => _historicalData?.hasData ?? false;

  HourlyPrice? get currentHourPrice {
    if (_todayData == null) return null;
    final currentHour = DateTime.now().hour;
    if (currentHour < _todayData!.hourlyPrices.length) {
      return _todayData!.hourlyPrices[currentHour];
    }
    return null;
  }

  Future<void> initialize() async {
    _settings = await _storageService.loadSettings();
    notifyListeners();

    if (_settings.apiKey.isNotEmpty) {
      await fetchAllData();
      _startAutoRefresh();
      _startAutoTcpSend();
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    final oldApiKey = _settings.apiKey;
    final oldDomain = _settings.domain;
    final oldInterval = _settings.refreshIntervalMinutes;
    final oldTcpInterval = _settings.tcpSendIntervalSeconds;
    final oldTcpAutoSend = _settings.tcpAutoSendEnabled;
    final oldHistoricalPeriod = _settings.historicalPeriod;

    _settings = newSettings;
    await _storageService.saveSettings(newSettings);
    notifyListeners();

    // Se l'API key, il dominio o il periodo storico sono cambiati, ricarica tutto incluso storico
    if (newSettings.apiKey != oldApiKey ||
        newSettings.domain != oldDomain ||
        newSettings.historicalPeriod != oldHistoricalPeriod) {
      _historicalData = null; // Reset storico
      await _storageService.clearHistoricalCache(); // Pulisci cache
      await fetchAllData();
    } else if (!hasData) {
      await fetchAllData();
    }

    // Se l'intervallo e' cambiato, riavvia il timer
    if (newSettings.refreshIntervalMinutes != oldInterval) {
      _startAutoRefresh();
    }

    // Se l'intervallo TCP o l'abilitazione sono cambiati, riavvia il timer TCP
    if (newSettings.tcpSendIntervalSeconds != oldTcpInterval ||
        newSettings.tcpAutoSendEnabled != oldTcpAutoSend) {
      _startAutoTcpSend();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();

    if (_settings.apiKey.isEmpty) return;

    _refreshTimer = Timer.periodic(
      Duration(minutes: _settings.refreshIntervalMinutes),
      (_) => fetchDailyData(), // Solo dati giornalieri, non storico
    );
  }

  void _startAutoTcpSend() {
    _tcpSendTimer?.cancel();

    // Non avviare se disabilitato o se mancano le configurazioni
    if (!_settings.tcpAutoSendEnabled ||
        _settings.tcpIpAddress.isEmpty ||
        _settings.apiKey.isEmpty) {
      return;
    }

    // Assicurati che l'intervallo sia nel range valido (30-600 secondi)
    final intervalSeconds = _settings.tcpSendIntervalSeconds.clamp(30, 600);

    _tcpSendTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => sendDataViaTcp(),
    );
  }

  /// Fetch completo: prima storico (30gg), poi giornalieri
  Future<void> fetchAllData() async {
    if (_settings.apiKey.isEmpty) {
      _lastError = 'API Key non configurata';
      notifyListeners();
      return;
    }

    // Se non abbiamo dati storici, li carichiamo prima
    if (_historicalData == null || !_historicalData!.hasData) {
      await fetchHistoricalData();
    }

    // Poi carichiamo i dati giornalieri
    await fetchDailyData();
  }

  /// Fetch dati storici per calcolo soglie (periodo configurabile)
  /// Usa la cache per velocizzare: carica da storage e aggiorna solo i giorni mancanti
  Future<void> fetchHistoricalData() async {
    if (_settings.apiKey.isEmpty) return;

    _isLoadingHistorical = true;
    notifyListeners();

    final periodDays = _settings.historicalPeriod.days;
    final domain = _settings.domain;

    try {
      // Prova a caricare dalla cache
      var cache = await _storageService.loadHistoricalCache();

      // Verifica se la cache è valida per il dominio e periodo correnti
      if (cache != null && cache.isValidFor(domain, periodDays)) {
        // Cache valida, verifica se è aggiornata
        if (cache.isUpToDate) {
          // Cache aggiornata oggi, usa direttamente
          _historicalData = cache.toHistoricalData();
          _isLoadingHistorical = false;
          notifyListeners();
          return;
        }

        // Cache non aggiornata, aggiorna incrementalmente
        cache = await _updateCacheIncrementally(cache, periodDays);
      } else {
        // Nessuna cache valida, scarica tutto
        cache = await _fetchAllHistoricalData(periodDays);
      }

      // Salva la cache aggiornata
      if (cache != null) {
        await _storageService.saveHistoricalCache(cache);
        _historicalData = cache.toHistoricalData();
      }
    } catch (e) {
      _historicalData = HistoricalPriceData(
        error: 'Errore caricamento storico: $e',
      );
    }

    _isLoadingHistorical = false;
    notifyListeners();
  }

  /// Aggiorna la cache incrementalmente: rimuove vecchi giorni, aggiunge nuovi
  Future<HistoricalPriceCache?> _updateCacheIncrementally(
    HistoricalPriceCache cache,
    int periodDays,
  ) async {
    final service = EntsoeService(securityToken: _settings.apiKey);

    // Rimuovi giorni troppo vecchi
    cache = cache.pruneOldDays(periodDays);

    // Trova giorni mancanti
    final missingDays = cache.getMissingDays(periodDays);

    if (missingDays.isEmpty) {
      // Nessun giorno mancante, aggiorna solo il timestamp
      return HistoricalPriceCache(
        domain: cache.domain,
        periodDays: cache.periodDays,
        dailyPrices: cache.dailyPrices,
        lastUpdate: DateTime.now(),
      );
    }

    // Scarica solo i giorni mancanti
    for (final date in missingDays) {
      final response = await service.getDayAheadPrices(
        _settings.domain,
        EntsoeService.formatDateForApi(date),
      );

      if (!response.hasError && response.prices.isNotEmpty) {
        cache = cache.addDayData(date, response.prices);
      }

      // Piccola pausa per evitare rate limiting
      await Future.delayed(const Duration(milliseconds: 50));
    }

    return cache;
  }

  /// Scarica tutti i dati storici (nessuna cache o cache invalida)
  Future<HistoricalPriceCache?> _fetchAllHistoricalData(int periodDays) async {
    final service = EntsoeService(securityToken: _settings.apiKey);
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final startDate = now.subtract(Duration(days: periodDays));

    final dailyPrices = <String, List<double>>{};
    var currentDate = startDate;

    while (currentDate.isBefore(yesterday) ||
        currentDate.isAtSameMomentAs(yesterday)) {
      final response = await service.getDayAheadPrices(
        _settings.domain,
        EntsoeService.formatDateForApi(currentDate),
      );

      if (!response.hasError && response.prices.isNotEmpty) {
        final dateKey = '${currentDate.year}-'
            '${currentDate.month.toString().padLeft(2, '0')}-'
            '${currentDate.day.toString().padLeft(2, '0')}';
        dailyPrices[dateKey] = response.prices;
      }

      currentDate = currentDate.add(const Duration(days: 1));

      // Piccola pausa per evitare rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (dailyPrices.isEmpty) {
      return null;
    }

    return HistoricalPriceCache(
      domain: _settings.domain,
      periodDays: periodDays,
      dailyPrices: dailyPrices,
      lastUpdate: DateTime.now(),
    );
  }

  /// Fetch solo dati giornalieri (ieri, oggi, domani)
  Future<void> fetchDailyData() async {
    if (_settings.apiKey.isEmpty) {
      _lastError = 'API Key non configurata';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _lastError = null;
    _connectionStatus = _connectionStatus.copyWith(
      entsoeStatus: ConnectionState.connecting,
    );
    notifyListeners();

    final service = EntsoeService(securityToken: _settings.apiKey);
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));

    bool hasAnyError = false;
    String? errorMessage;

    // Fetch yesterday
    try {
      final yesterdayResponse = await service.getDayAheadPrices(
        _settings.domain,
        EntsoeService.formatDateForApi(yesterday),
      );
      if (!yesterdayResponse.hasError) {
        _yesterdayData = PriceCalculator.processEntsoeResponseWithHistory(
          yesterdayResponse,
          yesterday,
          _historicalData,
        );
      }
    } catch (e) {
      hasAnyError = true;
      errorMessage = 'Errore dati ieri: $e';
    }

    // Fetch today
    try {
      final todayResponse = await service.getDayAheadPrices(
        _settings.domain,
        EntsoeService.formatDateForApi(now),
      );
      if (!todayResponse.hasError) {
        _todayData = PriceCalculator.processEntsoeResponseWithHistory(
          todayResponse,
          now,
          _historicalData,
        );
      } else {
        hasAnyError = true;
        errorMessage = todayResponse.error;
      }
    } catch (e) {
      hasAnyError = true;
      errorMessage = 'Errore dati oggi: $e';
    }

    // Fetch tomorrow
    try {
      final tomorrowResponse = await service.getDayAheadPrices(
        _settings.domain,
        EntsoeService.formatDateForApi(tomorrow),
      );
      if (!tomorrowResponse.hasError) {
        _tomorrowData = PriceCalculator.processEntsoeResponseWithHistory(
          tomorrowResponse,
          tomorrow,
          _historicalData,
        );
      }
      // Non segnaliamo errore per domani, potrebbe non essere ancora disponibile
    } catch (_) {
      // I dati di domani potrebbero non essere disponibili
    }

    _isLoading = false;

    if (hasAnyError) {
      _connectionStatus = _connectionStatus.copyWith(
        entsoeStatus: ConnectionState.error,
        entsoeError: errorMessage,
      );
      _lastError = errorMessage;
    } else {
      _connectionStatus = _connectionStatus.copyWith(
        entsoeStatus: ConnectionState.connected,
        entsoeError: null,
        lastEntsoeSync: DateTime.now(),
      );
    }

    notifyListeners();

    // Avvia il timer TCP automatico se abilitato e non gia' attivo
    if (hasData && _settings.tcpAutoSendEnabled && _tcpSendTimer == null) {
      // Invia subito la prima volta, poi il timer gestira' gli invii successivi
      await sendDataViaTcp();
      _startAutoTcpSend();
    }
  }

  /// Invia il comando Impr al server dView con la percentuale di potenza corrente
  /// Formato: {"impr":"all","heat":XX,"fan":XX}\n
  Future<void> sendDataViaTcp() async {
    if (_todayData == null) {
      _connectionStatus = _connectionStatus.copyWith(
        tcpStatus: ConnectionState.error,
        tcpError: 'Nessun dato disponibile per oggi',
      );
      notifyListeners();
      return;
    }

    _connectionStatus = _connectionStatus.copyWith(
      tcpStatus: ConnectionState.connecting,
    );
    notifyListeners();

    // Usa il nuovo metodo sendCurrentHourImpr per inviare il comando Impr
    final result = await _tcpService.sendCurrentHourImpr(
      _settings.tcpIpAddress,
      _settings.tcpPort,
      _todayData,
    );

    if (result.success) {
      _connectionStatus = _connectionStatus.copyWith(
        tcpStatus: ConnectionState.connected,
        tcpError: null,
        lastTcpSend: DateTime.now(),
        lastTcpResponse: result.response,
      );
    } else {
      _connectionStatus = _connectionStatus.copyWith(
        tcpStatus: ConnectionState.error,
        tcpError: result.error,
      );
    }

    notifyListeners();
  }

  List<HourlyPrice> getAllPricesForChart() {
    List<HourlyPrice> allPrices = [];
    if (_yesterdayData != null) allPrices.addAll(_yesterdayData!.hourlyPrices);
    if (_todayData != null) allPrices.addAll(_todayData!.hourlyPrices);
    if (_tomorrowData != null) allPrices.addAll(_tomorrowData!.hourlyPrices);
    return allPrices;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tcpSendTimer?.cancel();
    super.dispose();
  }
}
