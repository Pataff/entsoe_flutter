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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Caricamento dati storici (30 giorni)...'),
                  SizedBox(height: 8),
                  Text(
                    'Necessario per calcolo soglie accurate',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  Text('Caricamento dati ENTSO-E...'),
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
                    'Andamento Prezzi (3 Giorni)',
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
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Three Tables Side by Side
                const Text(
                  'Dettaglio Orario',
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
                              'Ieri',
                              context,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDayTable(
                              provider.todayData,
                              'Oggi',
                              context,
                              isToday: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDayTable(
                              provider.tomorrowData,
                              'Domani',
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
                            'Oggi',
                            context,
                            isToday: true,
                          ),
                          const SizedBox(height: 16),
                          _buildDayTable(
                            provider.yesterdayData,
                            'Ieri',
                            context,
                          ),
                          const SizedBox(height: 16),
                          _buildDayTable(
                            provider.tomorrowData,
                            'Domani',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'Configura l\'applicazione',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Per iniziare, configura il tuo ENTSO-E Security Token '
              'e le altre impostazioni.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
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
              label: const Text('Vai alle Impostazioni'),
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
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    color: isToday ? Colors.blue : null,
                  ),
                ),
                if (data != null)
                  Text(
                    dateFormat.format(data.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
                  Icon(Icons.hourglass_empty, size: 32, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Non disponibile',
                    style: TextStyle(color: Colors.grey[600]),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue, width: 1.5),
          color: Colors.blue.withValues(alpha: 0.08),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 18, color: Colors.blue[800]),
                const SizedBox(width: 8),
                Text(
                  'Riferimento Storico (${historical.daysWithData} giorni)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue[800],
                  ),
                ),
                const Spacer(),
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
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHistoricalStat('Min', historical.minPrice, Colors.green[800]!),
                _buildHistoricalStat('Media', historical.avgPrice, Colors.blue[800]!),
                _buildHistoricalStat('Max', historical.maxPrice, Colors.red[800]!),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Soglie: <33% = 100% pot. | 33-66% = 50% pot. | >66% = 20% pot.',
                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalStat(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
