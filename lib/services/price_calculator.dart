import 'dart:math';
import '../models/price_data.dart';
import 'entsoe_service.dart';

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
  /// Usa soglie fisse basate sulla percentuale storica:
  /// Fascia 3: %i < 33% -> 100% potenza (basso costo)
  /// Fascia 2: 33% <= %i <= 66% -> 50% potenza (medio costo)
  /// Fascia 1: %i > 66% -> 20% potenza (alto costo)
  static int determinePowerBand(double percentage) {
    if (percentage < 33.0) {
      return 3; // Basso costo -> 100% potenza
    } else if (percentage <= 66.0) {
      return 2; // Medio costo -> 50% potenza
    } else {
      return 1; // Alto costo -> 20% potenza
    }
  }

  /// Determina la fascia di potenza considerando anche la media storica
  /// Regola chiave: se il prezzo supera la media, NON può essere 100% potenza
  /// Fascia 3: prezzo <= media E %i < 33% -> 100% potenza
  /// Fascia 2: prezzo <= media E %i >= 33% OPPURE prezzo > media E %i < 66% -> 50% potenza
  /// Fascia 1: %i >= 66% -> 20% potenza
  static int determinePowerBandWithAverage(double percentage, double price, double avgPrice) {
    // Se il prezzo supera il 66% del range -> sempre 20% potenza
    if (percentage >= 66.0) {
      return 1; // Alto costo -> 20% potenza
    }

    // Se il prezzo è sopra la media mensile -> massimo 50% potenza
    if (price > avgPrice) {
      return 2; // Sopra media -> 50% potenza (mai 100%)
    }

    // Prezzo sotto o uguale alla media
    if (percentage < 33.0) {
      return 3; // Basso costo E sotto media -> 100% potenza
    } else {
      return 2; // Medio costo -> 50% potenza
    }
  }

  /// Determina la fascia di potenza con soglie dinamiche basate su sigma
  /// (usato quando si hanno dati storici sufficienti)
  static int determinePowerBandDynamic(double percentage, double sigma) {
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

  /// Processa i dati di risposta ENTSO-E usando SOLO dati giornalieri (legacy)
  static DayPriceData? processEntsoeResponse(
    EntsoeResponse response,
    DateTime date,
  ) {
    return processEntsoeResponseWithHistory(response, date, null);
  }

  /// Processa i dati di risposta ENTSO-E usando riferimento STORICO
  /// Calcolo: Scarto Semplice Normalizzato dal Minimo
  /// - Percentuale: calcolata sui valori MIN/MAX del GIORNO in esame
  /// - Fascia di potenza: determinata confrontando con la MEDIA STORICA del periodo
  static DayPriceData? processEntsoeResponseWithHistory(
    EntsoeResponse response,
    DateTime date,
    HistoricalPriceData? historicalData,
  ) {
    if (response.hasError || response.prices.isEmpty) {
      return null;
    }

    final prices = response.prices;

    // Statistiche giornaliere (per calcolo percentuale e visualizzazione)
    final dayMinPrice = prices.reduce(min);
    final dayMaxPrice = prices.reduce(max);
    final dayAvgPrice = prices.reduce((a, b) => a + b) / prices.length;

    // Media storica per determinazione fascia di potenza
    final hasHistorical = historicalData?.hasData == true;
    final refAvgPrice = hasHistorical
        ? historicalData!.avgPrice
        : dayAvgPrice;
    final refStdDev = hasHistorical
        ? historicalData!.stdDeviation
        : 0.0;

    // Calcola le percentuali usando MIN/MAX del GIORNO (non storico)
    // Formula: %i = ((Ci - Cmin_giorno) / (Cmax_giorno - Cmin_giorno)) × 100
    final percentages = prices
        .map((p) => calculatePercentage(p, dayMinPrice, dayMaxPrice))
        .toList();

    // Crea la lista di prezzi orari con tutte le informazioni
    List<HourlyPrice> hourlyPrices = [];
    for (int i = 0; i < prices.length && i < 24; i++) {
      final dateTime = DateTime(date.year, date.month, date.day, i);
      final percentage = percentages[i].clamp(0.0, 100.0);

      // Determina fascia di potenza:
      // - Percentuale calcolata sul giorno
      // - Confronto con media STORICA del periodo selezionato
      final powerBand = hasHistorical
          ? determinePowerBandWithAverage(percentage, prices[i], refAvgPrice)
          : determinePowerBand(percentage);

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
      minPrice: dayMinPrice,
      maxPrice: dayMaxPrice,
      avgPrice: dayAvgPrice,
      stdDeviation: refStdDev,
    );
  }

  /// Ottiene un riepilogo testuale delle soglie
  static String getThresholdsSummary(double sigma) {
    return 'Soglie: Basso < ${(sigma / 2).toStringAsFixed(1)}%, '
        'Medio ${(sigma / 2).toStringAsFixed(1)}%-${sigma.toStringAsFixed(1)}%, '
        'Alto > ${sigma.toStringAsFixed(1)}%';
  }
}
