import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class CurrentHourCard extends StatelessWidget {
  const CurrentHourCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final currentPrice = provider.currentHourPrice;
        final yesterdayData = provider.yesterdayData;

        if (currentPrice == null) {
          return const SizedBox.shrink();
        }

        final bandColor = _getColorForBand(currentPrice.powerBand);
        final currentHour = currentPrice.dateTime.hour;

        // Calculate price difference vs yesterday
        double? priceDiff;
        double? priceDiffPercent;
        if (yesterdayData != null &&
            currentHour < yesterdayData.hourlyPrices.length) {
          final yesterdayPrice = yesterdayData.hourlyPrices[currentHour].price;
          priceDiff = currentPrice.price - yesterdayPrice;
          priceDiffPercent = (priceDiff / yesterdayPrice) * 100;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // First cell: Power percentage circle
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(
                                  value: currentPrice.powerPercentage / 100,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.grey.withValues(
                                    alpha: 0.2,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    bandColor,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${currentPrice.powerPercentage}%',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: bandColor,
                                    ),
                                  ),
                                  Text(
                                    'Power',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: bandColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'BAND ${currentPrice.powerBand}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Second cell: Current hour range
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bandColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: bandColor, width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: bandColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Time Slot',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: bandColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${currentHour.toString().padLeft(2, '0')}:00 - ${(currentHour + 1).toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: bandColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Third cell: Price
                  Expanded(
                    flex: 2,
                    child: _buildInfoCell(
                      context,
                      'Current Price',
                      currentPrice.price.toStringAsFixed(2),
                      'EUR/MWh',
                      Icons.euro,
                      Colors.blue,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Fourth cell: Percentage deviation
                  Expanded(
                    flex: 2,
                    child: _buildInfoCell(
                      context,
                      'Deviation',
                      '${currentPrice.percentage.toStringAsFixed(1)}%',
                      'from min',
                      Icons.trending_up,
                      Colors.purple,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Fifth cell: Difference vs yesterday
                  Expanded(
                    flex: 2,
                    child:
                        priceDiff != null
                            ? _buildDiffCell(
                              context,
                              priceDiff,
                              priceDiffPercent!,
                            )
                            : _buildInfoCell(
                              context,
                              'vs Yesterday',
                              'N/A',
                              '',
                              Icons.compare_arrows,
                              Colors.grey,
                            ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCell(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use darker shade for better contrast
    final textColor = HSLColor.fromColor(color).withLightness(0.3).toColor();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: isDark ? color : textColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? color : textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : textColor,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiffCell(BuildContext context, double diff, double diffPercent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = diff > 0;
    final isNegative = diff < 0;
    final color =
        isPositive ? Colors.red : (isNegative ? Colors.green : Colors.grey);
    // Use darker shade for better contrast
    final textColor =
        isPositive
            ? Colors.red[800]!
            : (isNegative ? Colors.green[800]! : Colors.grey[700]!);
    final icon =
        isPositive
            ? Icons.arrow_upward
            : (isNegative ? Icons.arrow_downward : Icons.remove);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.compare_arrows,
                size: 12,
                color: isDark ? color : textColor,
              ),
              const SizedBox(width: 4),
              Text(
                'vs Yesterday',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? color : textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isDark ? color : textColor),
              Text(
                diff.abs().toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? color : textColor,
                ),
              ),
            ],
          ),
          Text(
            '${isPositive ? '+' : ''}${diffPercent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? color : textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForBand(int band) {
    switch (band) {
      case 3:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForBand(int band) {
    switch (band) {
      case 3:
        return Icons.bolt;
      case 2:
        return Icons.power_settings_new;
      case 1:
        return Icons.power_off;
      default:
        return Icons.help_outline;
    }
  }
}
