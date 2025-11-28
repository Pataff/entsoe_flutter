import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/entsoe_service.dart';

class HistoricalTrendChart extends StatefulWidget {
  final List<DailyPriceStats> dailyStats;
  final GlobalPriceStats? globalStats;

  const HistoricalTrendChart({
    super.key,
    required this.dailyStats,
    this.globalStats,
  });

  @override
  State<HistoricalTrendChart> createState() => _HistoricalTrendChartState();
}

class _HistoricalTrendChartState extends State<HistoricalTrendChart> {
  bool _showAvgPrice = true;
  bool _showMaxPrice = true;
  bool _showMinPrice = true;
  bool _showGlobalAvg = true;
  bool _showGlobalMax = false;
  bool _showGlobalMin = false;

  @override
  Widget build(BuildContext context) {
    if (widget.dailyStats.isEmpty) {
      return const Center(child: Text('No historical data available'));
    }

    // Calculate Y axis bounds
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final stat in widget.dailyStats) {
      if (_showMinPrice) {
        minY = min(minY, stat.minPrice);
      }
      if (_showMaxPrice) {
        maxY = max(maxY, stat.maxPrice);
      }
      if (_showAvgPrice) {
        minY = min(minY, stat.avgPrice);
        maxY = max(maxY, stat.avgPrice);
      }
    }

    // Include global stats in bounds if shown
    if (widget.globalStats != null) {
      if (_showGlobalMin) minY = min(minY, widget.globalStats!.minPrice);
      if (_showGlobalMax) maxY = max(maxY, widget.globalStats!.maxPrice);
      if (_showGlobalAvg) {
        minY = min(minY, widget.globalStats!.avgPrice);
        maxY = max(maxY, widget.globalStats!.avgPrice);
      }
    }

    if (minY == double.infinity) {
      minY = 0;
      maxY = 100;
    }

    // Add padding to Y axis
    final yPadding = (maxY - minY) * 0.1;
    minY -= yPadding;
    maxY += yPadding;

    final dateFormat = DateFormat('dd/MM', 'it_IT');
    final monthFormat = DateFormat('MMM', 'it_IT');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Historical Price Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Filter toggles - Daily traces
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildFilterChip(
                  'Daily Avg',
                  Colors.blue,
                  _showAvgPrice,
                  (v) => setState(() => _showAvgPrice = v),
                ),
                _buildFilterChip(
                  'Daily Max',
                  Colors.red,
                  _showMaxPrice,
                  (v) => setState(() => _showMaxPrice = v),
                ),
                _buildFilterChip(
                  'Daily Min',
                  Colors.green,
                  _showMinPrice,
                  (v) => setState(() => _showMinPrice = v),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Filter toggles - Global reference lines
            if (widget.globalStats != null)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _buildFilterChip(
                    'Period Avg',
                    Colors.purple,
                    _showGlobalAvg,
                    (v) => setState(() => _showGlobalAvg = v),
                  ),
                  _buildFilterChip(
                    'Period Max',
                    Colors.orange,
                    _showGlobalMax,
                    (v) => setState(() => _showGlobalMax = v),
                  ),
                  _buildFilterChip(
                    'Period Min',
                    Colors.teal,
                    _showGlobalMin,
                    (v) => setState(() => _showGlobalMin = v),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            // Chart
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (widget.dailyStats.length - 1).toDouble(),
                  minY: minY.floorToDouble(),
                  maxY: maxY.ceilToDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: ((maxY - minY) / 5).clamp(5, 50),
                    verticalInterval: (widget.dailyStats.length / 12).clamp(1, 30),
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
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _calculateXInterval(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= widget.dailyStats.length) {
                            return const SizedBox.shrink();
                          }
                          final date = widget.dailyStats[index].date;
                          // Show month name at the start of each month
                          if (date.day <= 7 || index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                monthFormat.format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              dateFormat.format(date),
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                        reservedSize: 28,
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
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) {
                        if (spots.isEmpty) return [];

                        final index = spots.first.x.toInt();
                        if (index < 0 || index >= widget.dailyStats.length) {
                          return [];
                        }

                        final stat = widget.dailyStats[index];
                        final fullDateFormat = DateFormat('EEE d MMM yyyy', 'it_IT');

                        return spots.map((spot) {
                          String label;
                          Color color;

                          // Determine which line this is
                          final barIndex = spot.barIndex;
                          int lineIndex = 0;

                          if (_showAvgPrice && barIndex == lineIndex) {
                            label = 'Avg';
                            color = Colors.blue;
                          } else if (_showMaxPrice && barIndex == (lineIndex += _showAvgPrice ? 1 : 0)) {
                            label = 'Max';
                            color = Colors.red;
                          } else if (_showMinPrice) {
                            label = 'Min';
                            color = Colors.green;
                          } else {
                            return null;
                          }

                          return LineTooltipItem(
                            '${fullDateFormat.format(stat.date)}\n$label: ${spot.y.toStringAsFixed(2)} EUR/MWh',
                            TextStyle(color: color, fontSize: 11),
                          );
                        }).whereType<LineTooltipItem>().toList();
                      },
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: _buildGlobalReferenceLines(),
                  ),
                  lineBarsData: _buildLineBars(),
                ),
              ),
            ),
            // Legend for global stats
            if (widget.globalStats != null) ...[
              const Divider(),
              _buildGlobalStatsLegend(),
            ],
          ],
        ),
      ),
    );
  }

  double _calculateXInterval() {
    final count = widget.dailyStats.length;
    if (count <= 14) return 1;
    if (count <= 30) return 7;
    if (count <= 90) return 14;
    if (count <= 180) return 30;
    return 30;
  }

  List<HorizontalLine> _buildGlobalReferenceLines() {
    if (widget.globalStats == null) return [];

    final lines = <HorizontalLine>[];

    if (_showGlobalAvg) {
      lines.add(HorizontalLine(
        y: widget.globalStats!.avgPrice,
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
          labelResolver: (_) => 'Avg: ${widget.globalStats!.avgPrice.toStringAsFixed(1)}',
        ),
      ));
    }

    if (_showGlobalMax) {
      lines.add(HorizontalLine(
        y: widget.globalStats!.maxPrice,
        color: Colors.orange,
        strokeWidth: 2,
        dashArray: [4, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          labelResolver: (_) => 'Max: ${widget.globalStats!.maxPrice.toStringAsFixed(1)}',
        ),
      ));
    }

    if (_showGlobalMin) {
      lines.add(HorizontalLine(
        y: widget.globalStats!.minPrice,
        color: Colors.teal,
        strokeWidth: 2,
        dashArray: [4, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.bottomRight,
          style: const TextStyle(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          labelResolver: (_) => 'Min: ${widget.globalStats!.minPrice.toStringAsFixed(1)}',
        ),
      ));
    }

    return lines;
  }

  List<LineChartBarData> _buildLineBars() {
    final bars = <LineChartBarData>[];

    // Average price line - Blue
    if (_showAvgPrice) {
      bars.add(LineChartBarData(
        spots: widget.dailyStats.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value.avgPrice);
        }).toList(),
        isCurved: true,
        curveSmoothness: 0.2,
        color: Colors.blue,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: Colors.blue.withValues(alpha: 0.1),
        ),
      ));
    }

    // Max price line - Red
    if (_showMaxPrice) {
      bars.add(LineChartBarData(
        spots: widget.dailyStats.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value.maxPrice);
        }).toList(),
        isCurved: true,
        curveSmoothness: 0.2,
        color: Colors.red,
        barWidth: 1.5,
        isStrokeCapRound: true,
        dashArray: [4, 2],
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    // Min price line - Green
    if (_showMinPrice) {
      bars.add(LineChartBarData(
        spots: widget.dailyStats.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value.minPrice);
        }).toList(),
        isCurved: true,
        curveSmoothness: 0.2,
        color: Colors.green,
        barWidth: 1.5,
        isStrokeCapRound: true,
        dashArray: [4, 2],
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return bars;
  }

  Widget _buildGlobalStatsLegend() {
    final stats = widget.globalStats!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Period Min', stats.minPrice, Colors.teal),
        _buildStatItem('Period Avg', stats.avgPrice, Colors.purple),
        _buildStatItem('Period Max', stats.maxPrice, Colors.orange),
      ],
    );
  }

  Widget _buildStatItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${value.toStringAsFixed(1)} EUR/MWh',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, Color color, bool selected, Function(bool) onChanged) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: onChanged,
      selectedColor: color.withValues(alpha: 0.3),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: selected ? color : Colors.grey,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      side: BorderSide(color: selected ? color : Colors.grey),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
