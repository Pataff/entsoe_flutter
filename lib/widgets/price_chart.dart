import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/price_data.dart';

class PriceChart extends StatelessWidget {
  final DayPriceData dayData;

  const PriceChart({super.key, required this.dayData});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: dayData.maxPrice * 1.1,
            minY: 0,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.blueGrey.shade800,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final hour = group.x.toInt();
                  final price = dayData.hourlyPrices[hour];
                  return BarTooltipItem(
                    '${hour.toString().padLeft(2, '0')}:00\n'
                    '${price.price.toStringAsFixed(2)} EUR/MWh\n'
                    '${price.percentage.toStringAsFixed(1)}%\n'
                    '${price.powerBandLabel}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() % 3 == 0) {
                      return Text(
                        '${value.toInt()}h',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }
                    return const Text('');
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (dayData.maxPrice / 5).clamp(10, 50),
            ),
            barGroups: dayData.hourlyPrices.asMap().entries.map((entry) {
              final index = entry.key;
              final hourlyPrice = entry.value;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: hourlyPrice.price,
                    color: _getColorForBand(hourlyPrice.powerBand),
                    width: 10,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Color _getColorForBand(int band) {
    switch (band) {
      case 3:
        return Colors.green; // Basso costo - 100%
      case 2:
        return Colors.orange; // Medio costo - 50%
      case 1:
        return Colors.red; // Alto costo - 20%
      default:
        return Colors.grey;
    }
  }
}
