import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/price_data.dart';

class MultiDayChart extends StatefulWidget {
  final DayPriceData? yesterday;
  final DayPriceData? today;
  final DayPriceData? tomorrow;
  final double? historicalAvgPrice;
  final String? historicalPeriodLabel;

  const MultiDayChart({
    super.key,
    this.yesterday,
    this.today,
    this.tomorrow,
    this.historicalAvgPrice,
    this.historicalPeriodLabel,
  });

  @override
  State<MultiDayChart> createState() => _MultiDayChartState();
}

class _MultiDayChartState extends State<MultiDayChart> {
  bool _showYesterday = true;
  bool _showToday = true;
  bool _showTomorrow = true;
  bool _showAvgLine = true;

  @override
  Widget build(BuildContext context) {
    final hasYesterday = widget.yesterday != null;
    final hasToday = widget.today != null;
    final hasTomorrow = widget.tomorrow != null;

    if (!hasYesterday && !hasToday && !hasTomorrow) {
      return const Center(child: Text('Nessun dato disponibile'));
    }

    // Calculate min/max across all visible data from actual hourly prices
    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;

    if (_showYesterday && hasYesterday) {
      for (final p in widget.yesterday!.hourlyPrices) {
        minPrice = min(minPrice, p.price);
        maxPrice = max(maxPrice, p.price);
      }
    }
    if (_showToday && hasToday) {
      for (final p in widget.today!.hourlyPrices) {
        minPrice = min(minPrice, p.price);
        maxPrice = max(maxPrice, p.price);
      }
    }
    if (_showTomorrow && hasTomorrow) {
      for (final p in widget.tomorrow!.hourlyPrices) {
        minPrice = min(minPrice, p.price);
        maxPrice = max(maxPrice, p.price);
      }
    }

    // Include historical average in min/max calculation if shown
    if (_showAvgLine && widget.historicalAvgPrice != null) {
      minPrice = min(minPrice, widget.historicalAvgPrice!);
      maxPrice = max(maxPrice, widget.historicalAvgPrice!);
    }

    if (minPrice == double.infinity) {
      minPrice = 0;
      maxPrice = 100;
    }

    final currentHour = DateTime.now().hour;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Filter toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasYesterday)
                  _buildFilterChip(
                    'Ieri',
                    Colors.orange,
                    _showYesterday,
                    (v) => setState(() => _showYesterday = v),
                  ),
                if (hasToday)
                  _buildFilterChip(
                    'Oggi',
                    Colors.blue,
                    _showToday,
                    (v) => setState(() => _showToday = v),
                  ),
                if (hasTomorrow)
                  _buildFilterChip(
                    'Domani',
                    Colors.green,
                    _showTomorrow,
                    (v) => setState(() => _showTomorrow = v),
                  ),
                if (widget.historicalAvgPrice != null)
                  _buildFilterChip(
                    'Media ${widget.historicalPeriodLabel ?? ''}',
                    Colors.purple,
                    _showAvgLine,
                    (v) => setState(() => _showAvgLine = v),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Chart
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 23,
                  minY: (minPrice - 5).floorToDouble(),
                  maxY: (maxPrice + 5).ceilToDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: ((maxPrice - minPrice) / 5).clamp(5, 20),
                    verticalInterval: 3,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('Ora', style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 3,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('EUR/MWh', style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey.shade800,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          String dayLabel;
                          Color color;
                          DayPriceData? data;

                          if (spot.barIndex == 0 && _showYesterday && hasYesterday) {
                            dayLabel = 'Ieri';
                            color = Colors.orange;
                            data = widget.yesterday;
                          } else if (spot.barIndex == 1 && _showToday && hasToday) {
                            dayLabel = 'Oggi';
                            color = Colors.blue;
                            data = widget.today;
                          } else {
                            dayLabel = 'Domani';
                            color = Colors.green;
                            data = widget.tomorrow;
                          }

                          final hour = spot.x.toInt();
                          final price = data?.hourlyPrices[hour];

                          return LineTooltipItem(
                            '$dayLabel ${hour}:00\n${spot.y.toStringAsFixed(2)} EUR/MWh'
                            '${price != null ? '\n${price.percentage.toStringAsFixed(1)}%' : ''}',
                            TextStyle(color: color, fontSize: 11),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      if (_showToday && hasToday)
                        VerticalLine(
                          x: currentHour.toDouble(),
                          color: Colors.red,
                          strokeWidth: 2,
                          dashArray: [5, 5],
                          label: VerticalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            labelResolver: (_) => 'Ora',
                          ),
                        ),
                    ],
                    horizontalLines: [
                      if (_showAvgLine && widget.historicalAvgPrice != null)
                        HorizontalLine(
                          y: widget.historicalAvgPrice!,
                          color: Colors.purple,
                          strokeWidth: 2,
                          dashArray: [8, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            labelResolver: (_) => 'Media ${widget.historicalAvgPrice!.toStringAsFixed(1)}',
                          ),
                        ),
                    ],
                  ),
                  lineBarsData: _buildLineBars(hasYesterday, hasToday, hasTomorrow),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<LineChartBarData> _buildLineBars(bool hasYesterday, bool hasToday, bool hasTomorrow) {
    List<LineChartBarData> bars = [];

    // Yesterday - Orange
    if (_showYesterday && hasYesterday) {
      bars.add(_createLineBar(widget.yesterday!, Colors.orange, [8, 4]));
    }

    // Today - Blue (solid)
    if (_showToday && hasToday) {
      bars.add(_createLineBar(widget.today!, Colors.blue, null));
    }

    // Tomorrow - Green
    if (_showTomorrow && hasTomorrow) {
      bars.add(_createLineBar(widget.tomorrow!, Colors.green, [4, 4]));
    }

    return bars;
  }

  LineChartBarData _createLineBar(DayPriceData data, Color color, List<int>? dashArray) {
    return LineChartBarData(
      spots: data.hourlyPrices.map((p) {
        return FlSpot(p.dateTime.hour.toDouble(), p.price);
      }).toList(),
      isCurved: true,
      curveSmoothness: 0.2,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dashArray: dashArray,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
            color: color,
            strokeWidth: 1,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildFilterChip(String label, Color color, bool selected, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onChanged,
        selectedColor: color.withValues(alpha: 0.3),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: selected ? color : Colors.grey,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(color: selected ? color : Colors.grey),
      ),
    );
  }
}
