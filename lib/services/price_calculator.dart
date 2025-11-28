import 'dart:math';
import '../models/price_data.dart';
import '../models/app_settings.dart';
import 'entsoe_service.dart';

/// Algorithm parameters for quantile-based power modulation
class AlgorithmParams {
  final double pLow; // Lower percentile price threshold (EUR/MWh)
  final double pHigh; // Upper percentile price threshold (EUR/MWh)
  final double minReduction; // Minimum reduction percentage (0-100)
  final double maxReduction; // Maximum reduction percentage (0-100)
  final double exponent; // Non-linear exponent (>= 1.0)

  const AlgorithmParams({
    required this.pLow,
    required this.pHigh,
    required this.minReduction,
    required this.maxReduction,
    required this.exponent,
  });

  /// Creates params from AppSettings and historical cache
  factory AlgorithmParams.fromSettings(
    AppSettings settings,
    HistoricalPriceCache? cache,
  ) {
    // Get percentile thresholds from historical data
    final thresholds = cache?.getPercentileThresholds(
      settings.lowPercentile,
      settings.highPercentile,
      periodDays: settings.historicalPeriod.days,
    );

    // Default fallback values if no historical data
    final pLow = thresholds?.$1 ?? 0.0;
    final pHigh = thresholds?.$2 ?? 100.0;

    return AlgorithmParams(
      pLow: pLow,
      pHigh: pHigh,
      minReduction: settings.minReduction,
      maxReduction: settings.maxReduction,
      exponent: settings.nonLinearExponent,
    );
  }

  /// Fallback params when no historical data is available
  /// Uses daily min/max as thresholds
  factory AlgorithmParams.fallbackFromDailyRange(
    double dayMin,
    double dayMax,
    AppSettings settings,
  ) {
    // Use daily range with percentile positions as approximation
    final range = dayMax - dayMin;
    final pLow = dayMin + range * settings.lowPercentile;
    final pHigh = dayMin + range * settings.highPercentile;

    return AlgorithmParams(
      pLow: pLow,
      pHigh: pHigh,
      minReduction: settings.minReduction,
      maxReduction: settings.maxReduction,
      exponent: settings.nonLinearExponent,
    );
  }
}

class PriceCalculator {
  /// Calculates the normalized beta value (0-1) for a given price
  /// Formula: β = (price - p_low) / (p_high - p_low) clamped to [0, 1]
  static double calculateBeta(double price, double pLow, double pHigh) {
    if (pHigh <= pLow) return 0.5; // Prevent division by zero
    final beta = (price - pLow) / (pHigh - pLow);
    return beta.clamp(0.0, 1.0);
  }

  /// Applies non-linear transformation to beta
  /// Formula: β_nl = β^n where n >= 1
  static double applyNonLinear(double beta, double exponent) {
    if (exponent < 1.0) return beta;
    return pow(beta, exponent).toDouble();
  }

  /// Calculates the power reduction percentage
  /// Formula: Reduction% = R_min + β_nl × (R_max - R_min)
  static double calculateReduction(
    double betaNonLinear,
    double minReduction,
    double maxReduction,
  ) {
    return minReduction + betaNonLinear * (maxReduction - minReduction);
  }

  /// Calculates the power setpoint percentage
  /// Formula: Setpoint% = 100% - Reduction%
  static int calculateSetpoint(double reduction) {
    final setpoint = 100.0 - reduction;
    return setpoint.round().clamp(0, 100);
  }

  /// Full calculation: price -> setpoint percentage
  /// Implements the complete quantile-based non-linear algorithm
  static int calculatePowerSetpoint(double price, AlgorithmParams params) {
    // Step 1: Calculate normalized beta
    final beta = calculateBeta(price, params.pLow, params.pHigh);

    // Step 2: Apply non-linear transformation
    final betaNl = applyNonLinear(beta, params.exponent);

    // Step 3: Calculate reduction percentage
    final reduction = calculateReduction(
      betaNl,
      params.minReduction,
      params.maxReduction,
    );

    // Step 4: Convert to setpoint
    return calculateSetpoint(reduction);
  }

  /// Calculates the percentage position of price in the quantile range (for display)
  /// Returns 0-100% where 0% = at or below p_low, 100% = at or above p_high
  static double calculatePercentage(double price, double pLow, double pHigh) {
    final beta = calculateBeta(price, pLow, pHigh);
    return beta * 100;
  }

  /// Process ENTSO-E response with quantile-based algorithm
  /// Uses historical percentile thresholds for accurate power modulation
  static DayPriceData? processEntsoeResponseWithQuantiles(
    EntsoeResponse response,
    DateTime date,
    AlgorithmParams params,
  ) {
    if (response.hasError || response.prices.isEmpty) {
      return null;
    }

    final prices = response.prices;

    // Daily statistics for display
    final dayMinPrice = prices.reduce(min);
    final dayMaxPrice = prices.reduce(max);
    final dayAvgPrice = prices.reduce((a, b) => a + b) / prices.length;

    // Calculate standard deviation
    final variance = prices
            .map((p) => (p - dayAvgPrice) * (p - dayAvgPrice))
            .reduce((a, b) => a + b) /
        prices.length;
    final stdDev = variance > 0 ? sqrt(variance) : 0.0;

    // Create hourly price data with calculated setpoints
    List<HourlyPrice> hourlyPrices = [];
    for (int i = 0; i < prices.length && i < 24; i++) {
      final dateTime = DateTime(date.year, date.month, date.day, i);
      final price = prices[i];

      // Calculate percentage position in quantile range (for display)
      final percentage = calculatePercentage(price, params.pLow, params.pHigh);

      // Calculate power setpoint using the full non-linear algorithm
      final powerPercentage = calculatePowerSetpoint(price, params);

      hourlyPrices.add(HourlyPrice(
        dateTime: dateTime,
        price: price,
        percentage: percentage,
        powerPercentage: powerPercentage,
      ));
    }

    return DayPriceData(
      date: date,
      hourlyPrices: hourlyPrices,
      minPrice: dayMinPrice,
      maxPrice: dayMaxPrice,
      avgPrice: dayAvgPrice,
      stdDeviation: stdDev,
    );
  }

  /// Legacy method for backwards compatibility
  /// Processes response without historical data using daily range
  static DayPriceData? processEntsoeResponse(
    EntsoeResponse response,
    DateTime date,
    AppSettings settings,
  ) {
    if (response.hasError || response.prices.isEmpty) {
      return null;
    }

    final prices = response.prices;
    final dayMin = prices.reduce(min);
    final dayMax = prices.reduce(max);

    // Create fallback params using daily range
    final params = AlgorithmParams.fallbackFromDailyRange(dayMin, dayMax, settings);

    return processEntsoeResponseWithQuantiles(response, date, params);
  }

  /// Legacy compatibility method
  static DayPriceData? processEntsoeResponseWithHistory(
    EntsoeResponse response,
    DateTime date,
    HistoricalPriceData? historicalData,
    AppSettings? settings,
  ) {
    if (response.hasError || response.prices.isEmpty) {
      return null;
    }

    final prices = response.prices;
    final dayMin = prices.reduce(min);
    final dayMax = prices.reduce(max);

    // Use default settings if not provided
    final effectiveSettings = settings ?? AppSettings();

    // If we have historical data with min/max, use those as thresholds
    // This is a fallback when we don't have the cache for percentile calculation
    AlgorithmParams params;
    if (historicalData != null && historicalData.hasData) {
      params = AlgorithmParams(
        pLow: historicalData.minPrice,
        pHigh: historicalData.maxPrice,
        minReduction: effectiveSettings.minReduction,
        maxReduction: effectiveSettings.maxReduction,
        exponent: effectiveSettings.nonLinearExponent,
      );
    } else {
      params = AlgorithmParams.fallbackFromDailyRange(dayMin, dayMax, effectiveSettings);
    }

    return processEntsoeResponseWithQuantiles(response, date, params);
  }

  /// Gets a summary of the algorithm parameters
  static String getAlgorithmSummary(AlgorithmParams params) {
    return 'Thresholds: P_low=${params.pLow.toStringAsFixed(1)}, '
        'P_high=${params.pHigh.toStringAsFixed(1)} EUR/MWh\n'
        'Reduction: ${params.minReduction.toStringAsFixed(0)}%-${params.maxReduction.toStringAsFixed(0)}%, '
        'Exponent: ${params.exponent.toStringAsFixed(1)}';
  }
}
