/// Enum for historical reference period
enum HistoricalPeriod {
  oneWeek(7, '1 week'),
  twoWeeks(14, '2 weeks'),
  threeWeeks(21, '3 weeks'),
  oneMonth(30, '1 month'),
  threeMonths(90, '3 months'),
  sixMonths(180, '6 months'),
  nineMonths(270, '9 months'),
  oneYear(365, '1 year');

  final int days;
  final String label;
  const HistoricalPeriod(this.days, this.label);
}

class AppSettings {
  final String apiKey;
  final int refreshIntervalMinutes;
  final String domain;
  final String domainName;
  final String tcpIpAddress;
  final int tcpPort;
  final int tcpSendIntervalSeconds; // TCP send interval (30-600 seconds)
  final bool tcpAutoSendEnabled; // Enable automatic TCP send
  final HistoricalPeriod historicalPeriod; // Period for historical min/max calculation

  // Quantile-based algorithm parameters
  final double lowPercentile; // Lower percentile threshold (0.0-1.0, default 0.2 = 20th)
  final double highPercentile; // Upper percentile threshold (0.0-1.0, default 0.8 = 80th)
  final double minReduction; // Minimum power reduction % (0-100, default 0)
  final double maxReduction; // Maximum power reduction % (0-100, default 90)
  final double nonLinearExponent; // Exponent for non-linear curve (>= 1.0, default 2.0)

  AppSettings({
    this.apiKey = '',
    this.refreshIntervalMinutes = 60,
    this.domain = '10Y1001A1001A73I',
    this.domainName = 'IT-North BZ',
    this.tcpIpAddress = '192.168.1.100',
    this.tcpPort = 8080,
    this.tcpSendIntervalSeconds = 300, // Default 5 minutes for ramp control
    this.tcpAutoSendEnabled = true,
    this.historicalPeriod = HistoricalPeriod.oneMonth, // Default 1 month
    // Quantile algorithm defaults
    this.lowPercentile = 0.2, // 20th percentile
    this.highPercentile = 0.8, // 80th percentile
    this.minReduction = 0.0, // 0% minimum reduction
    this.maxReduction = 90.0, // 90% maximum reduction
    this.nonLinearExponent = 2.0, // Quadratic curve
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
    HistoricalPeriod? historicalPeriod,
    double? lowPercentile,
    double? highPercentile,
    double? minReduction,
    double? maxReduction,
    double? nonLinearExponent,
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
      historicalPeriod: historicalPeriod ?? this.historicalPeriod,
      lowPercentile: lowPercentile ?? this.lowPercentile,
      highPercentile: highPercentile ?? this.highPercentile,
      minReduction: minReduction ?? this.minReduction,
      maxReduction: maxReduction ?? this.maxReduction,
      nonLinearExponent: nonLinearExponent ?? this.nonLinearExponent,
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
        'historicalPeriod': historicalPeriod.name,
        'lowPercentile': lowPercentile,
        'highPercentile': highPercentile,
        'minReduction': minReduction,
        'maxReduction': maxReduction,
        'nonLinearExponent': nonLinearExponent,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // Parse historical period from string
    HistoricalPeriod period = HistoricalPeriod.oneMonth;
    if (json['historicalPeriod'] != null) {
      period = HistoricalPeriod.values.firstWhere(
        (e) => e.name == json['historicalPeriod'],
        orElse: () => HistoricalPeriod.oneMonth,
      );
    }

    return AppSettings(
      apiKey: json['apiKey'] ?? '',
      refreshIntervalMinutes: json['refreshIntervalMinutes'] ?? 60,
      domain: json['domain'] ?? '10Y1001A1001A73I',
      domainName: json['domainName'] ?? 'IT-North BZ',
      tcpIpAddress: json['tcpIpAddress'] ?? '192.168.1.100',
      tcpPort: json['tcpPort'] ?? 8080,
      tcpSendIntervalSeconds: json['tcpSendIntervalSeconds'] ?? 300,
      tcpAutoSendEnabled: json['tcpAutoSendEnabled'] ?? true,
      historicalPeriod: period,
      lowPercentile: (json['lowPercentile'] as num?)?.toDouble() ?? 0.2,
      highPercentile: (json['highPercentile'] as num?)?.toDouble() ?? 0.8,
      minReduction: (json['minReduction'] as num?)?.toDouble() ?? 0.0,
      maxReduction: (json['maxReduction'] as num?)?.toDouble() ?? 90.0,
      nonLinearExponent: (json['nonLinearExponent'] as num?)?.toDouble() ?? 2.0,
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
