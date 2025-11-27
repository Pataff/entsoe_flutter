import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/price_data.dart';

class PriceTable extends StatelessWidget {
  final DayPriceData dayData;

  const PriceTable({super.key, required this.dayData});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final currentHour = DateTime.now().hour;
    final isToday = _isToday(dayData.date);

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.primaryContainer,
          ),
          columns: const [
            DataColumn(label: Text('Ora', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
              label: Text('Prezzo (EUR/MWh)', style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true,
            ),
            DataColumn(
              label: Text('Scostamento %', style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true,
            ),
            DataColumn(label: Text('Fascia', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
              label: Text('Potenza', style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true,
            ),
          ],
          rows: dayData.hourlyPrices.map((hourlyPrice) {
            final isCurrentHour = isToday && hourlyPrice.dateTime.hour == currentHour;

            return DataRow(
              color: isCurrentHour
                  ? WidgetStateProperty.all(Colors.blue.withOpacity(0.2))
                  : null,
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrentHour)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.arrow_right, size: 16, color: Colors.blue),
                        ),
                      Text(
                        timeFormat.format(hourlyPrice.dateTime),
                        style: TextStyle(
                          fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    hourlyPrice.price.toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${hourlyPrice.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                DataCell(_buildBandChip(hourlyPrice.powerBand)),
                DataCell(
                  Text(
                    '${hourlyPrice.powerPercentage}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getColorForBand(hourlyPrice.powerBand),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildBandChip(int band) {
    String label;
    Color color;

    switch (band) {
      case 3:
        label = 'Basso';
        color = Colors.green;
        break;
      case 2:
        label = 'Medio';
        color = Colors.orange;
        break;
      case 1:
        label = 'Alto';
        color = Colors.red;
        break;
      default:
        label = 'N/A';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
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
