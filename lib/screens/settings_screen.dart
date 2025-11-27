import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/app_settings.dart';

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
  late int _refreshInterval;
  late DomainInfo _selectedDomain;
  late bool _tcpAutoSendEnabled;
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
    _refreshInterval = settings.refreshIntervalMinutes;
    _tcpAutoSendEnabled = settings.tcpAutoSendEnabled;
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
    super.dispose();
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      final tcpInterval = int.tryParse(_tcpIntervalController.text) ?? 60;

      final newSettings = AppSettings(
        apiKey: _apiKeyController.text.trim(),
        refreshIntervalMinutes: _refreshInterval,
        domain: _selectedDomain.code,
        domainName: _selectedDomain.fullName,
        tcpIpAddress: _tcpAddressController.text.trim(),
        tcpPort: int.tryParse(_tcpPortController.text) ?? 8080,
        tcpSendIntervalSeconds: tcpInterval.clamp(30, 600),
        tcpAutoSendEnabled: _tcpAutoSendEnabled,
      );

      context.read<AppProvider>().updateSettings(newSettings);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impostazioni salvate'),
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
        title: const Text('Configurazione'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                        hintText: 'Inserisci il tuo ENTSO-E Security Token',
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
                          return 'Inserisci il Security Token';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ottieni il token su: transparency.entsoe.eu',
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
                          'Zona di Mercato',
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
                        labelText: 'Dominio/Zona',
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
                          'Aggiornamento Dati ENTSO-E',
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
                        labelText: 'Intervallo di aggiornamento',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 minuti')),
                        DropdownMenuItem(value: 30, child: Text('30 minuti')),
                        DropdownMenuItem(value: 60, child: Text('1 ora')),
                        DropdownMenuItem(value: 120, child: Text('2 ore')),
                        DropdownMenuItem(value: 360, child: Text('6 ore')),
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
                          'Server dView TCP/IP',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Indirizzo del server dView per invio comando Impr',
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
                              labelText: 'Indirizzo IP',
                              hintText: 'es. 192.168.1.100',
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
                              labelText: 'Porta',
                              hintText: '5000',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final port = int.tryParse(value);
                                if (port == null || port < 1 || port > 65535) {
                                  return 'Non valida';
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
                      title: const Text('Invio automatico'),
                      subtitle: const Text('Invia comando Impr automaticamente'),
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
                          labelText: 'Intervallo invio (secondi)',
                          hintText: '30-600 secondi',
                          border: OutlineInputBorder(),
                          helperText: 'Min: 30s, Max: 600s (10 minuti)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (_tcpAutoSendEnabled && value != null && value.isNotEmpty) {
                            final interval = int.tryParse(value);
                            if (interval == null || interval < 30 || interval > 600) {
                              return 'Intervallo non valido (30-600 secondi)';
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
              label: const Text('Salva Impostazioni'),
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
    final currentValue = int.tryParse(_tcpIntervalController.text) ?? 60;
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
}
