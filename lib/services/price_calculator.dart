import 'dart:math';
import '../models/price_data.dart';

class PriceCalculator {
  /// Calcola la Percentuale di Scostamento dal minimo
  /// Formula: %i = ((Ci - Cmin) / (Cmax - Cmin)) × 100
  static double calculatePercentage(double price, double minPrice, double maxPrice) {
    if (maxPrice == minPrice) return 0;
    return ((price - minPrice) / (maxPrice - minPrice)) * 100;
  }

  /// Calcola la deviazione standard delle percentuali
  static double calculateStdDeviation(List<double> percentages) {
    if (percentages.isEmpty) return 0;

    final mean = percentages.reduce((a, b) => a + b) / percentages.length;
    final squaredDiffs = percentages.map((p) => pow(p - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / percentages.length;
    return sqrt(variance);
  }

  /// Determina la fascia di potenza basata sulle soglie dinamiche
  /// Fascia 3: %i < sigma/2 -> 100% potenza (basso costo)
  /// Fascia 2: sigma/2 <= %i <= sigma -> 50% potenza (medio costo)
  /// Fascia 1: %i > sigma -> 20% potenza (alto costo)
  static int determinePowerBand(double percentage, double sigma) {
    final lowerThreshold = sigma / 2;
    final upperThreshold = sigma;

    if (percentage < lowerThreshold) {
      return 3; // Basso costo -> 100% potenza
    } else if (percentage <= upperThreshold) {
      return 2; // Medio costo -> 50% potenza
    } else {
      return 1; // Alto costo -> 20% potenza
    }
  }

  /// Processa i dati di risposta ENTSO-E e calcola tutti i valori
  static DayPriceData? processEntsoeResponse(
    EntsoeResponse response,
    DateTime date,
  ) {
    if (response.hasError || response.prices.isEmpty) {
      return null;
    }

    final prices = response.prices;
    final minPrice = prices.reduce(min);
    final maxPrice = prices.reduce(max);
    final avgPrice = prices.reduce((a, b) => a + b) / prices.length;

    // Calcola le percentuali per ogni ora
    final percentages = prices
        .map((p) => calculatePercentage(p, minPrice, maxPrice))
        .toList();

    // Calcola la deviazione standard delle percentuali
    final stdDev = calculateStdDeviation(percentages);

    // Crea la lista di prezzi orari con tutte le informazioni
    List<HourlyPrice> hourlyPrices = [];
    for (int i = 0; i < prices.length && i < 24; i++) {
      final dateTime = DateTime(date.year, date.month, date.day, i);
      final percentage = percentages[i];
      final powerBand = determinePowerBand(percentage, stdDev);

      hourlyPrices.add(HourlyPrice(
        dateTime: dateTime,
        price: prices[i],
        percentage: percentage,
        powerBand: powerBand,
      ));
    }

    return DayPriceData(
      date: date,
      hourlyPrices: hourlyPrices,
      minPrice: minPrice,
      maxPrice: maxPrice,
      avgPrice: avgPrice,
      stdDeviation: stdDev,
    );
  }

  /// Ottiene un riepilogo testuale delle soglie
  static String getThresholdsSummary(double sigma) {
    return 'Soglie: Basso < ${(sigma / 2).toStringAsFixed(1)}%, '
        'Medio ${(sigma / 2).toStringAsFixed(1)}%-${sigma.toStringAsFixed(1)}%, '
        'Alto > ${sigma.toStringAsFixed(1)}%';
  }
}
