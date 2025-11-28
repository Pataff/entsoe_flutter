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
  HistoricalPriceCache? _historicalCache; // Cache for percentile calculations
  AlgorithmParams? _algorithmParams; // Current algorithm parameters
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
  HistoricalPriceCache? get historicalCache => _historicalCache;
  AlgorithmParams? get algorithmParams => _algorithmParams;
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
    // Track algorithm parameter changes
    final algorithmChanged =
        newSettings.lowPercentile != _settings.lowPercentile ||
        newSettings.highPercentile != _settings.highPercentile ||
        newSettings.minReduction != _settings.minReduction ||
        newSettings.maxReduction != _settings.maxReduction ||
        newSettings.nonLinearExponent != _settings.nonLinearExponent;

    _settings = newSettings;
    await _storageService.saveSettings(newSettings);
    notifyListeners();

    // If API key or domain changed, reload everything including historical data
    // Period change does NOT invalidate cache (always uses 1 year of cache)
    if (newSettings.apiKey != oldApiKey || newSettings.domain != oldDomain) {
      _historicalData = null;
      _historicalCache = null;
      _algorithmParams = null;
      await _storageService.clearHistoricalCache();
      await fetchAllData();
    } else if (newSettings.historicalPeriod != oldHistoricalPeriod || algorithmChanged) {
      // If period or algorithm params changed, recalculate from existing cache
      await _recalculateHistoricalFromCache();
      // Reload daily data to apply new parameters
      await fetchDailyData();
    } else if (!hasData) {
      await fetchAllData();
    }

    // Restart refresh timer if interval changed
    if (newSettings.refreshIntervalMinutes != oldInterval) {
      _startAutoRefresh();
    }

    // Restart TCP timer if interval or enabled state changed
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

  /// Full fetch: first historical data, then daily data
  Future<void> fetchAllData() async {
    if (_settings.apiKey.isEmpty) {
      _lastError = 'API Key not configured';
      notifyListeners();
      return;
    }

    // If we don't have historical data, load it first
    if (_historicalData == null || !_historicalData!.hasData) {
      await fetchHistoricalData();
    }

    // Then load daily data
    await fetchDailyData();
  }

  /// Fetch historical data for threshold calculation
  /// Cache always stores 1 year of data, but uses only selected period for calculations
  Future<void> fetchHistoricalData() async {
    if (_settings.apiKey.isEmpty) return;

    _isLoadingHistorical = true;
    notifyListeners();

    final periodDays = _settings.historicalPeriod.days;
    final domain = _settings.domain;

    try {
      // Try to load from cache
      var cache = await _storageService.loadHistoricalCache();

      // Check if cache is valid for domain (period doesn't affect validity)
      if (cache != null && cache.isValidForDomain(domain)) {
        // Cache valid for domain, check if up to date
        if (cache.isUpToDate) {
          // Cache updated today, use directly with period filter
          _historicalCache = cache;
          _historicalData = cache.toHistoricalData(periodDays: periodDays);
          _algorithmParams = AlgorithmParams.fromSettings(_settings, cache);
          _isLoadingHistorical = false;
          notifyListeners();
          return;
        }

        // Cache not updated, update incrementally (always 1 year)
        cache = await _updateCacheIncrementally(cache);
      } else {
        // No valid cache, download all (1 year)
        cache = await _fetchAllHistoricalData();
      }

      // Save updated cache
      if (cache != null) {
        await _storageService.saveHistoricalCache(cache);
        _historicalCache = cache;
        // Extract only data for selected period
        _historicalData = cache.toHistoricalData(periodDays: periodDays);
        // Create algorithm params from cache
        _algorithmParams = AlgorithmParams.fromSettings(_settings, cache);
      }
    } catch (e) {
      _historicalData = HistoricalPriceData(
        error: 'Error loading historical data: $e',
      );
    }

    _isLoadingHistorical = false;
    notifyListeners();
  }

  /// Recalculates historical data from existing cache with new period/algorithm params
  Future<void> _recalculateHistoricalFromCache() async {
    _isLoadingHistorical = true;
    notifyListeners();

    try {
      var cache = _historicalCache;
      cache ??= await _storageService.loadHistoricalCache();

      if (cache != null && cache.isValidForDomain(_settings.domain)) {
        _historicalCache = cache;
        _historicalData = cache.toHistoricalData(
          periodDays: _settings.historicalPeriod.days,
        );
        // Recalculate algorithm params with new settings
        _algorithmParams = AlgorithmParams.fromSettings(_settings, cache);
      }
    } catch (e) {
      // If fails, keep current historical data
    }

    _isLoadingHistorical = false;
    notifyListeners();
  }

  /// Updates cache incrementally: removes days > 1 year, adds new ones
  Future<HistoricalPriceCache?> _updateCacheIncrementally(
    HistoricalPriceCache cache,
  ) async {
    final service = EntsoeService(securityToken: _settings.apiKey);

    // Remove days older than 1 year
    cache = cache.pruneOldDays();

    // Find missing days (always based on 1 year)
    final missingDays = cache.getMissingDays();

    if (missingDays.isEmpty) {
      // No missing days, just update timestamp
      return HistoricalPriceCache(
        domain: cache.domain,
        dailyPrices: cache.dailyPrices,
        lastUpdate: DateTime.now(),
      );
    }

    // Download only missing days
    for (final date in missingDays) {
      final response = await service.getDayAheadPrices(
        _settings.domain,
        EntsoeService.formatDateForApi(date),
      );

      if (!response.hasError && response.prices.isNotEmpty) {
        cache = cache.addDayData(date, response.prices);
      }

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 50));
    }

    return cache;
  }

  /// Downloads all historical data (always 1 year of cache)
  Future<HistoricalPriceCache?> _fetchAllHistoricalData() async {
    final service = EntsoeService(securityToken: _settings.apiKey);
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    // Always 1 year of cache
    final startDate = now.subtract(
      const Duration(days: HistoricalPriceCache.cacheStorageDays),
    );

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

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (dailyPrices.isEmpty) {
      return null;
    }

    return HistoricalPriceCache(
      domain: _settings.domain,
      dailyPrices: dailyPrices,
      lastUpdate: DateTime.now(),
    );
  }

  /// Fetch daily data only (yesterday, today, tomorrow)
  Future<void> fetchDailyData() async {
    if (_settings.apiKey.isEmpty) {
      _lastError = 'API Key not configured';
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

    // Get or create algorithm params
    final params = _algorithmParams ??
        AlgorithmParams.fromSettings(_settings, _historicalCache);

    // Fetch yesterday
    try {
      final yesterdayResponse = await service.getDayAheadPrices(
        _settings.domain,
        EntsoeService.formatDateForApi(yesterday),
      );
      if (!yesterdayResponse.hasError) {
        _yesterdayData = PriceCalculator.processEntsoeResponseWithQuantiles(
          yesterdayResponse,
          yesterday,
          params,
        );
      }
    } catch (e) {
      hasAnyError = true;
      errorMessage = 'Error fetching yesterday data: $e';
    }

    // Fetch today
    try {
      final todayResponse = await service.getDayAheadPrices(
        _settings.domain,
        EntsoeService.formatDateForApi(now),
      );
      if (!todayResponse.hasError) {
        _todayData = PriceCalculator.processEntsoeResponseWithQuantiles(
          todayResponse,
          now,
          params,
        );
      } else {
        hasAnyError = true;
        errorMessage = todayResponse.error;
      }
    } catch (e) {
      hasAnyError = true;
      errorMessage = 'Error fetching today data: $e';
    }

    // Fetch tomorrow
    try {
      final tomorrowResponse = await service.getDayAheadPrices(
        _settings.domain,
        EntsoeService.formatDateForApi(tomorrow),
      );
      if (!tomorrowResponse.hasError) {
        _tomorrowData = PriceCalculator.processEntsoeResponseWithQuantiles(
          tomorrowResponse,
          tomorrow,
          params,
        );
      }
      // Don't report error for tomorrow, it might not be available yet
    } catch (_) {
      // Tomorrow's data might not be available
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

    // Start automatic TCP timer if enabled and not already active
    if (hasData && _settings.tcpAutoSendEnabled && _tcpSendTimer == null) {
      // Send immediately first time, then timer will handle subsequent sends
      await sendDataViaTcp();
      _startAutoTcpSend();
    }
  }

  /// Sends the Impr command to dView server with current power percentage
  /// Format: {"impr":"all","heat":XX,"fan":XX}\n
  Future<void> sendDataViaTcp() async {
    if (_todayData == null) {
      _connectionStatus = _connectionStatus.copyWith(
        tcpStatus: ConnectionState.error,
        tcpError: 'No data available for today',
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
