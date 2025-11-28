import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/app_settings.dart';
import 'help_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiKeyController;
  late TextEditingController _tcpAddressController;
  late TextEditingController _tcpPortController;
  late TextEditingController _tcpIntervalController;
  late TextEditingController _minReductionController;
  late TextEditingController _maxReductionController;
  late TextEditingController _exponentController;
  late int _refreshInterval;
  late DomainInfo _selectedDomain;
  late bool _tcpAutoSendEnabled;
  late HistoricalPeriod _historicalPeriod;
  late double _lowPercentile;
  late double _highPercentile;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppProvider>().settings;
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _tcpAddressController = TextEditingController(text: settings.tcpIpAddress);
    _tcpPortController = TextEditingController(
      text: settings.tcpPort.toString(),
    );
    _tcpIntervalController = TextEditingController(
      text: settings.tcpSendIntervalSeconds.toString(),
    );
    _minReductionController = TextEditingController(
      text: settings.minReduction.toStringAsFixed(0),
    );
    _maxReductionController = TextEditingController(
      text: settings.maxReduction.toStringAsFixed(0),
    );
    _exponentController = TextEditingController(
      text: settings.nonLinearExponent.toStringAsFixed(1),
    );
    _refreshInterval = settings.refreshIntervalMinutes;
    _tcpAutoSendEnabled = settings.tcpAutoSendEnabled;
    _historicalPeriod = settings.historicalPeriod;
    _lowPercentile = settings.lowPercentile;
    _highPercentile = settings.highPercentile;
    _selectedDomain = availableDomains.firstWhere(
      (d) => d.code == settings.domain,
      orElse: () => availableDomains.first,
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _tcpAddressController.dispose();
    _tcpPortController.dispose();
    _tcpIntervalController.dispose();
    _minReductionController.dispose();
    _maxReductionController.dispose();
    _exponentController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      final tcpInterval = int.tryParse(_tcpIntervalController.text) ?? 300;
      final minReduction = double.tryParse(_minReductionController.text) ?? 0.0;
      final maxReduction = double.tryParse(_maxReductionController.text) ?? 90.0;
      final exponent = double.tryParse(_exponentController.text) ?? 2.0;

      final newSettings = AppSettings(
        apiKey: _apiKeyController.text.trim(),
        refreshIntervalMinutes: _refreshInterval,
        domain: _selectedDomain.code,
        domainName: _selectedDomain.fullName,
        tcpIpAddress: _tcpAddressController.text.trim(),
        tcpPort: int.tryParse(_tcpPortController.text) ?? 8080,
        tcpSendIntervalSeconds: tcpInterval.clamp(30, 600),
        tcpAutoSendEnabled: _tcpAutoSendEnabled,
        historicalPeriod: _historicalPeriod,
        lowPercentile: _lowPercentile.clamp(0.0, 1.0),
        highPercentile: _highPercentile.clamp(0.0, 1.0),
        minReduction: minReduction.clamp(0.0, 100.0),
        maxReduction: maxReduction.clamp(0.0, 100.0),
        nonLinearExponent: exponent.clamp(1.0, 5.0),
      );

      context.read<AppProvider>().updateSettings(newSettings);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // API Key Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.key, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'ENTSO-E API',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        labelText: 'Security Token',
                        hintText: 'Enter your ENTSO-E Security Token',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed:
                              () => setState(
                                () => _obscureApiKey = !_obscureApiKey,
                              ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the Security Token';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get token at: transparency.entsoe.eu',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Domain/Zone Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Market Zone',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DomainInfo>(
                      initialValue: _selectedDomain,
                      decoration: const InputDecoration(
                        labelText: 'Domain/Zone',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          availableDomains.map((domain) {
                            return DropdownMenuItem(
                              value: domain,
                              child: Text(
                                '${domain.shortName} - ${domain.fullName}',
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedDomain = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Refresh Interval Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ENTSO-E Data Refresh',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _refreshInterval,
                      decoration: const InputDecoration(
                        labelText: 'Refresh interval',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 minutes')),
                        DropdownMenuItem(value: 30, child: Text('30 minutes')),
                        DropdownMenuItem(value: 60, child: Text('1 hour')),
                        DropdownMenuItem(value: 120, child: Text('2 hours')),
                        DropdownMenuItem(value: 360, child: Text('6 hours')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _refreshInterval = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Historical Period Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Historical Period',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Period for Min/Max/Avg reference calculation',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<HistoricalPeriod>(
                      initialValue: _historicalPeriod,
                      decoration: const InputDecoration(
                        labelText: 'Reference period',
                        border: OutlineInputBorder(),
                      ),
                      items: HistoricalPeriod.values.map((period) {
                        return DropdownMenuItem(
                          value: period,
                          child: Text(period.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _historicalPeriod = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Algorithm Parameters Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.functions,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Power Algorithm',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 20),
                          tooltip: 'Learn more',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HelpScreen()),
                            );
                          },
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quantile-based non-linear power modulation',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    // Percentile thresholds
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Low Percentile: ${(_lowPercentile * 100).toInt()}%',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Slider(
                                value: _lowPercentile,
                                min: 0.05,
                                max: 0.45,
                                divisions: 8,
                                label: '${(_lowPercentile * 100).toInt()}%',
                                onChanged: (value) {
                                  setState(() => _lowPercentile = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'High Percentile: ${(_highPercentile * 100).toInt()}%',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Slider(
                                value: _highPercentile,
                                min: 0.55,
                                max: 0.95,
                                divisions: 8,
                                label: '${(_highPercentile * 100).toInt()}%',
                                onChanged: (value) {
                                  setState(() => _highPercentile = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Reduction parameters
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minReductionController,
                            decoration: const InputDecoration(
                              labelText: 'Min Reduction %',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              helperText: 'At low price',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final val = double.tryParse(value);
                                if (val == null || val < 0 || val > 100) {
                                  return 'Invalid (0-100)';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _maxReductionController,
                            decoration: const InputDecoration(
                              labelText: 'Max Reduction %',
                              hintText: '90',
                              border: OutlineInputBorder(),
                              helperText: 'At high price',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final val = double.tryParse(value);
                                if (val == null || val < 0 || val > 100) {
                                  return 'Invalid (0-100)';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Non-linear exponent
                    TextFormField(
                      controller: _exponentController,
                      decoration: const InputDecoration(
                        labelText: 'Non-linear Exponent',
                        hintText: '2.0',
                        border: OutlineInputBorder(),
                        helperText: 'Higher = more aggressive at high prices (1.0 = linear)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final val = double.tryParse(value);
                          if (val == null || val < 1.0 || val > 5.0) {
                            return 'Invalid (1.0-5.0)';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Quick exponent buttons
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildExponentChip('Linear', 1.0),
                        _buildExponentChip('Quadratic', 2.0),
                        _buildExponentChip('Cubic', 3.0),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // TCP/IP Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.router,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'dView TCP/IP Server',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'dView server address for Impr command',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _tcpAddressController,
                            decoration: const InputDecoration(
                              labelText: 'IP Address',
                              hintText: 'e.g. 192.168.1.100',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _tcpPortController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              hintText: '5000',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final port = int.tryParse(value);
                                if (port == null || port < 1 || port > 65535) {
                                  return 'Invalid';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Auto send switch
                    SwitchListTile(
                      title: const Text('Auto send'),
                      subtitle: const Text('Send Impr command automatically'),
                      value: _tcpAutoSendEnabled,
                      onChanged: (value) {
                        setState(() => _tcpAutoSendEnabled = value);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_tcpAutoSendEnabled) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _tcpIntervalController,
                        decoration: const InputDecoration(
                          labelText: 'Send interval (seconds)',
                          hintText: '30-600 seconds',
                          border: OutlineInputBorder(),
                          helperText: 'Min: 30s, Max: 600s (10 minutes)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (_tcpAutoSendEnabled && value != null && value.isNotEmpty) {
                            final interval = int.tryParse(value);
                            if (interval == null || interval < 30 || interval > 600) {
                              return 'Invalid interval (30-600 seconds)';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // Quick interval buttons
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildIntervalChip('30s', 30),
                          _buildIntervalChip('1m', 60),
                          _buildIntervalChip('2m', 120),
                          _buildIntervalChip('5m', 300),
                          _buildIntervalChip('10m', 600),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalChip(String label, int seconds) {
    final currentValue = int.tryParse(_tcpIntervalController.text) ?? 300;
    final isSelected = currentValue == seconds;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _tcpIntervalController.text = seconds.toString();
          });
        }
      },
    );
  }

  Widget _buildExponentChip(String label, double exponent) {
    final currentValue = double.tryParse(_exponentController.text) ?? 2.0;
    final isSelected = (currentValue - exponent).abs() < 0.1;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _exponentController.text = exponent.toStringAsFixed(1);
          });
        }
      },
    );
  }
}
