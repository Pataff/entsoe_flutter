import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/price_data.dart';
import '../widgets/multi_day_chart.dart';
import '../widgets/compact_price_table.dart';
import '../widgets/connection_status_widget.dart';
import '../widgets/current_hour_card.dart';
import 'settings_screen.dart';
import 'historical_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ENTSO-E Monitor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoricalScreen()),
              );
            },
            tooltip: 'Analisi Storica',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AppProvider>().fetchAllData();
            },
            tooltip: 'Aggiorna dati',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Impostazioni',
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.settings.apiKey.isEmpty) {
            return _buildSetupPrompt(context);
          }

          if (provider.isLoadingHistorical) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading historical data (${provider.settings.historicalPeriod.label})...'),
                  const SizedBox(height: 8),
                  Text(
                    'Required for accurate threshold calculation',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading ENTSO-E data...'),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Status
                const ConnectionStatusWidget(),

                // Historical Reference Card
                if (provider.historicalData != null &&
                    provider.historicalData!.hasData)
                  _buildHistoricalReferenceCard(context, provider),

                // Current Hour Card
                if (provider.todayData != null) const CurrentHourCard(),

                const SizedBox(height: 16),

                // Multi-day Chart
                if (provider.hasData) ...[
                  const Text(
                    'Price Trend (3 Days)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: MultiDayChart(
                      yesterday: provider.yesterdayData,
                      today: provider.todayData,
                      tomorrow: provider.tomorrowData,
                      historicalAvgPrice: provider.historicalData?.avgPrice,
                      historicalPeriodLabel: provider.settings.historicalPeriod.label,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Three Tables Side by Side
                const Text(
                  'Hourly Detail',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                LayoutBuilder(
                  builder: (context, constraints) {
                    // Use Row for wide screens, Column for narrow
                    if (constraints.maxWidth > 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildDayTable(
                              provider.yesterdayData,
                              'Yesterday',
                              context,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDayTable(
                              provider.todayData,
                              'Today',
                              context,
                              isToday: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDayTable(
                              provider.tomorrowData,
                              'Tomorrow',
                              context,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Stacked layout for narrow screens
                      return Column(
                        children: [
                          _buildDayTable(
                            provider.todayData,
                            'Today',
                            context,
                            isToday: true,
                          ),
                          const SizedBox(height: 16),
                          _buildDayTable(
                            provider.yesterdayData,
                            'Yesterday',
                            context,
                          ),
                          const SizedBox(height: 16),
                          _buildDayTable(
                            provider.tomorrowData,
                            'Tomorrow',
                            context,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSetupPrompt(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            const Text(
              'Configure the Application',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'To get started, configure your ENTSO-E Security Token '
              'and other settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Go to Settings'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTable(DayPriceData? data, String label, BuildContext context, {bool isToday = false}) {
    final dateFormat = DateFormat('EEE d/M', 'it_IT');
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isToday
                  ? Colors.blue.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: isToday
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.blue[400] : theme.colorScheme.onSurface,
                  ),
                ),
                if (data != null)
                  Text(
                    dateFormat.format(data.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // Table content
          if (data != null)
            CompactPriceTable(dayData: data, isToday: isToday)
          else
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    size: 32,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Not available',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoricalReferenceCard(BuildContext context, AppProvider provider) {
    final historical = provider.historicalData!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoricalScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue, width: 1.5),
            color: Colors.blue.withValues(alpha: 0.1),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, size: 18, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Historical Reference (${provider.settings.historicalPeriod.label})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${historical.dataMaturityPercent}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHistoricalStat(context, 'Min', historical.minPrice, Colors.green),
                  _buildHistoricalStat(context, 'Avg', historical.avgPrice, Colors.blue),
                  _buildHistoricalStat(context, 'Max', historical.maxPrice, Colors.red),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Thresholds: <33% = 100% pwr | 33-66% = 50% pwr | >66% = 20% pwr',
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoricalStat(BuildContext context, String label, double value, MaterialColor baseColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Use lighter shade for dark mode, darker shade for light mode
    final color = isDark ? baseColor[300]! : baseColor[700]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: baseColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'EUR/MWh',
            style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
