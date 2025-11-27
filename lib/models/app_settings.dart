class AppSettings {
  final String apiKey;
  final int refreshIntervalMinutes;
  final String domain;
  final String domainName;
  final String tcpIpAddress;
  final int tcpPort;
  final int tcpSendIntervalSeconds; // Intervallo invio TCP (30-600 secondi)
  final bool tcpAutoSendEnabled; // Abilita invio automatico TCP

  AppSettings({
    this.apiKey = '',
    this.refreshIntervalMinutes = 60,
    this.domain = '10Y1001A1001A73I',
    this.domainName = 'IT-North BZ',
    this.tcpIpAddress = '192.168.1.100',
    this.tcpPort = 8080,
    this.tcpSendIntervalSeconds = 60, // Default 60 secondi
    this.tcpAutoSendEnabled = true,
  });

  AppSettings copyWith({
    String? apiKey,
    int? refreshIntervalMinutes,
    String? domain,
    String? domainName,
    String? tcpIpAddress,
    int? tcpPort,
    int? tcpSendIntervalSeconds,
    bool? tcpAutoSendEnabled,
  }) {
    return AppSettings(
      apiKey: apiKey ?? this.apiKey,
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      domain: domain ?? this.domain,
      domainName: domainName ?? this.domainName,
      tcpIpAddress: tcpIpAddress ?? this.tcpIpAddress,
      tcpPort: tcpPort ?? this.tcpPort,
      tcpSendIntervalSeconds:
          tcpSendIntervalSeconds ?? this.tcpSendIntervalSeconds,
      tcpAutoSendEnabled: tcpAutoSendEnabled ?? this.tcpAutoSendEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'refreshIntervalMinutes': refreshIntervalMinutes,
        'domain': domain,
        'domainName': domainName,
        'tcpIpAddress': tcpIpAddress,
        'tcpPort': tcpPort,
        'tcpSendIntervalSeconds': tcpSendIntervalSeconds,
        'tcpAutoSendEnabled': tcpAutoSendEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      apiKey: json['apiKey'] ?? '',
      refreshIntervalMinutes: json['refreshIntervalMinutes'] ?? 60,
      domain: json['domain'] ?? '10Y1001A1001A73I',
      domainName: json['domainName'] ?? 'IT-North BZ',
      tcpIpAddress: json['tcpIpAddress'] ?? '192.168.1.100',
      tcpPort: json['tcpPort'] ?? 8080,
      tcpSendIntervalSeconds: json['tcpSendIntervalSeconds'] ?? 60,
      tcpAutoSendEnabled: json['tcpAutoSendEnabled'] ?? true,
    );
  }
}

class DomainInfo {
  final String code;
  final String shortName;
  final String fullName;
  final String timezone;

  const DomainInfo({
    required this.code,
    required this.shortName,
    required this.fullName,
    this.timezone = 'Europe/Rome',
  });
}

const List<DomainInfo> availableDomains = [
  DomainInfo(
      code: '10Y1001A1001A73I',
      shortName: 'IT_NORD',
      fullName: 'IT-North BZ',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10Y1001A1001A70O',
      shortName: 'IT_CNOR',
      fullName: 'IT-Centre-North BZ',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10Y1001A1001A71M',
      shortName: 'IT_CSUD',
      fullName: 'IT-Centre-South BZ',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10Y1001A1001A788',
      shortName: 'IT_SUD',
      fullName: 'IT-South BZ',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10Y1001A1001A74G',
      shortName: 'IT_SARD',
      fullName: 'IT-Sardinia BZ',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10Y1001A1001A75E',
      shortName: 'IT_SICI',
      fullName: 'IT-Sicily BZ',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10Y1001A1001A72K',
      shortName: 'IT_FOGN',
      fullName: 'IT-Foggia BZ',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10Y1001A1001A699',
      shortName: 'IT_BRNN',
      fullName: 'IT-Brindisi BZ',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10Y1001A1001A76C',
      shortName: 'IT_PRGP',
      fullName: 'IT-Priolo BZ',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10Y1001A1001A77A',
      shortName: 'IT_ROSN',
      fullName: 'IT-Rossano BZ',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10YIT-GRTN-----B',
      shortName: 'IT_CA',
      fullName: 'Italy CA/MBA',
      timezone: 'Europe/Rome'),
  DomainInfo(
      code: '10YFR-RTE------C',
      shortName: 'FR',
      fullName: 'France',
      timezone: 'Europe/Paris'),
  DomainInfo(
      code: '10YCB-GERMANY--8',
      shortName: 'DE',
      fullName: 'Germany',
      timezone: 'Europe/Berlin'),
  DomainInfo(
      code: '10YES-REE------0',
      shortName: 'ES',
      fullName: 'Spain',
      timezone: 'Europe/Madrid'),
  DomainInfo(
      code: '10YAT-APG------L',
      shortName: 'AT',
      fullName: 'Austria',
      timezone: 'Europe/Vienna'),
  DomainInfo(
      code: '10YBE----------2',
      shortName: 'BE',
      fullName: 'Belgium',
      timezone: 'Europe/Brussels'),
  DomainInfo(
      code: '10YNL----------L',
      shortName: 'NL',
      fullName: 'Netherlands',
      timezone: 'Europe/Amsterdam'),
];
