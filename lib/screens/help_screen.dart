import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.bolt,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Power Modulation Algorithm',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Optimize energy consumption based on market prices',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Overview
          _buildExpansionSection(
            context,
            icon: Icons.info_outline,
            title: 'Overview',
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildParagraph(
                  context,
                  'This app calculates optimal power levels for your devices based on electricity prices from the ENTSO-E market.',
                ),
                const SizedBox(height: 12),
                _buildHighlightBox(
                  context,
                  icon: Icons.trending_down,
                  color: Colors.green,
                  title: 'Low Price',
                  subtitle: 'Devices run at full power',
                ),
                const SizedBox(height: 8),
                _buildHighlightBox(
                  context,
                  icon: Icons.trending_up,
                  color: Colors.red,
                  title: 'High Price',
                  subtitle: 'Power is reduced to save money',
                ),
              ],
            ),
          ),

          // Algorithm Steps
          _buildExpansionSection(
            context,
            icon: Icons.analytics_outlined,
            title: 'How the Algorithm Works',
            child: Column(
              children: [
                _buildStepTile(context, 1, 'Gather Data',
                    'Download historical prices from ENTSO-E for your region'),
                _buildStepTile(context, 2, 'Calculate Thresholds',
                    'Find P_low (cheap) and P_high (expensive) using percentiles'),
                _buildStepTile(context, 3, 'Normalize Price',
                    'Convert current price to 0-1 range (0=cheap, 1=expensive)'),
                _buildStepTile(context, 4, 'Apply Curve',
                    'Transform using exponent for smoother response'),
                _buildStepTile(context, 5, 'Calculate Power',
                    'Power% = 100% - Reduction%', isLast: true),
              ],
            ),
          ),

          // Settings
          _buildExpansionSection(
            context,
            icon: Icons.tune,
            title: 'Settings Explained',
            child: Column(
              children: [
                _buildSettingCard(
                  context,
                  title: 'Low Percentile',
                  value: '20%',
                  description: 'Defines the "cheap" threshold',
                  detail: 'Prices in the lowest X% of historical data are considered cheap. At these prices, power runs at maximum.',
                  color: Colors.green,
                  icon: Icons.arrow_downward,
                ),
                _buildSettingCard(
                  context,
                  title: 'High Percentile',
                  value: '80%',
                  description: 'Defines the "expensive" threshold',
                  detail: 'Prices in the top X% of historical data trigger maximum power reduction.',
                  color: Colors.red,
                  icon: Icons.arrow_upward,
                ),
                _buildSettingCard(
                  context,
                  title: 'Min Reduction',
                  value: '0%',
                  description: 'Reduction at low prices',
                  detail: 'Power reduction when price is at or below P_low. Set to 0% for full power at cheap prices.',
                  color: Colors.blue,
                  icon: Icons.remove_circle_outline,
                ),
                _buildSettingCard(
                  context,
                  title: 'Max Reduction',
                  value: '90%',
                  description: 'Reduction at high prices',
                  detail: 'Maximum power reduction when price reaches P_high. 90% means devices run at only 10% power.',
                  color: Colors.orange,
                  icon: Icons.add_circle_outline,
                ),
                _buildSettingCard(
                  context,
                  title: 'Non-linear Exponent',
                  value: '2.0',
                  description: 'Curve aggressiveness',
                  detail: '1.0 = Linear response\n2.0 = Quadratic (recommended)\n3.0 = Cubic (aggressive)',
                  color: Colors.purple,
                  icon: Icons.show_chart,
                ),
              ],
            ),
          ),

          // Linear vs Non-Linear
          _buildExpansionSection(
            context,
            icon: Icons.compare_arrows,
            title: 'Linear vs Non-Linear',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildComparisonRow(
                  context,
                  title: 'Linear (n=1.0)',
                  description: 'Reduction increases evenly with price',
                  example: '50% price → 50% of max reduction',
                  color: Colors.blue,
                ),
                const Divider(height: 24),
                _buildComparisonRow(
                  context,
                  title: 'Quadratic (n=2.0)',
                  description: 'More power at medium prices, faster drop at high prices',
                  example: '50% price → only 25% of max reduction',
                  color: Colors.purple,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.amber[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Higher exponent = more power at medium prices, but sharper reduction when prices spike',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Example Calculation
          _buildExpansionSection(
            context,
            icon: Icons.calculate,
            title: 'Example Calculation',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFormulaBox(
                  context,
                  'Given',
                  'P_low = 50 EUR/MWh\nP_high = 150 EUR/MWh\nCurrent = 100 EUR/MWh\nExponent = 2.0\nMax Reduction = 90%',
                ),
                const SizedBox(height: 12),
                _buildFormulaBox(
                  context,
                  'Step 1: Normalize',
                  'β = (100 - 50) / (150 - 50) = 0.5',
                  highlight: true,
                ),
                const SizedBox(height: 8),
                _buildFormulaBox(
                  context,
                  'Step 2: Apply exponent',
                  'β_nl = 0.5² = 0.25',
                  highlight: true,
                ),
                const SizedBox(height: 8),
                _buildFormulaBox(
                  context,
                  'Step 3: Calculate reduction',
                  'Reduction = 0.25 × 90% = 22.5%',
                  highlight: true,
                ),
                const SizedBox(height: 8),
                _buildFormulaBox(
                  context,
                  'Step 4: Power setpoint',
                  'Power = 100% - 22.5% = 77.5%',
                  highlight: true,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Result',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '78%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[400],
                        ),
                      ),
                      Text(
                        'Power Setpoint',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Historical Period
          _buildExpansionSection(
            context,
            icon: Icons.history,
            title: 'Historical Period',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildParagraph(
                  context,
                  'The app uses past price data to determine what "cheap" and "expensive" mean for your region.',
                ),
                const SizedBox(height: 12),
                _buildPeriodOption(context, '1 month', 'Reacts quickly to seasonal changes'),
                _buildPeriodOption(context, '3 months', 'Balanced stability (recommended)'),
                _buildPeriodOption(context, '6 months', 'More stable thresholds'),
                _buildPeriodOption(context, '12 months', 'Full year reference'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[400], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The app caches 1 year of data locally but only uses your selected period for calculations.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Power Bands
          _buildExpansionSection(
            context,
            icon: Icons.palette,
            title: 'Power Bands (Colors)',
            child: Column(
              children: [
                _buildPowerBandCard(
                  context,
                  color: Colors.green,
                  band: 'Band 3',
                  range: '≥ 80%',
                  label: 'Low Cost',
                  description: 'Energy is cheap - run at high power',
                ),
                const SizedBox(height: 8),
                _buildPowerBandCard(
                  context,
                  color: Colors.orange,
                  band: 'Band 2',
                  range: '40-79%',
                  label: 'Medium Cost',
                  description: 'Moderate prices - reduce power',
                ),
                const SizedBox(height: 8),
                _buildPowerBandCard(
                  context,
                  color: Colors.red,
                  band: 'Band 1',
                  range: '< 40%',
                  label: 'High Cost',
                  description: 'Expensive - minimum power',
                ),
              ],
            ),
          ),

          // Tips
          _buildExpansionSection(
            context,
            icon: Icons.tips_and_updates,
            title: 'Tips',
            child: Column(
              children: [
                _buildTipItem(context, Icons.start, 'Start with default values and adjust based on results'),
                _buildTipItem(context, Icons.trending_down, 'Reduction too aggressive? Increase Low Percentile or decrease Max Reduction'),
                _buildTipItem(context, Icons.savings, 'Want more savings? Increase Max Reduction or Exponent'),
                _buildTipItem(context, Icons.timer, 'For heating/motors, use 5-minute TCP interval for smooth ramping'),
                _buildTipItem(context, Icons.visibility, 'Monitor Historical Reference card to see actual thresholds'),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildExpansionSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildHighlightBox(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(BuildContext context, int number, String title, String description, {bool isLast = false}) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required String title,
    required String value,
    required String description,
    required String detail,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontWeight: FontWeight.bold, color: color),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              detail,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    BuildContext context, {
    required String title,
    required String description,
    required String example,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  example,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormulaBox(BuildContext context, String label, String formula, {bool highlight = false}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.blue.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? Colors.blue.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.blue[400] : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formula,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodOption(BuildContext context, String period, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            period,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '- $description',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerBandCard(
    BuildContext context, {
    required Color color,
    required String band,
    required String range,
    required String label,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                range,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        band,
                        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.amber[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
