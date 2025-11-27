import 'package:flutter/material.dart';
import '../models/price_data.dart';

class CompactPriceTable extends StatelessWidget {
  final DayPriceData dayData;
  final bool isToday;

  const CompactPriceTable({
    super.key,
    required this.dayData,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentHour = DateTime.now().hour;

    return SizedBox(
      height: 400, // Fixed height for scrolling
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: dayData.hourlyPrices.length,
        itemBuilder: (context, index) {
          final price = dayData.hourlyPrices[index];
          final isCurrentHour = isToday && price.dateTime.hour == currentHour;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrentHour
                  ? Colors.blue.withValues(alpha: 0.2)
                  : (index.isEven ? Colors.grey.withValues(alpha: 0.05) : null),
              border: isCurrentHour
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                // Hour
                SizedBox(
                  width: 40,
                  child: Text(
                    '${price.dateTime.hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                // Price
                Expanded(
                  flex: 2,
                  child: Text(
                    '${price.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 4),
                // Percentage
                Expanded(
                  flex: 2,
                  child: Text(
                    '${price.percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 6),
                // Power band indicator
                Container(
                  width: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getColorForBand(price.powerBand).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getColorForBand(price.powerBand),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${price.powerPercentage}%',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _getColorForBand(price.powerBand),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
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
}
