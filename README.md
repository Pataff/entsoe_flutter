# ENTSO-E Energy Price Monitor

A Flutter application for monitoring and optimizing energy costs based on Day-Ahead prices from the ENTSO-E (European Network of Transmission System Operators for Electricity) platform.

## Description

The application retrieves electricity prices from the ENTSO-E Transparency Platform and automatically calculates optimal power bands for energy load management. Data is then sent via TCP to external control systems (e.g., dView) for dynamic consumption optimization.

## Features

### Price Monitoring
- Automatic retrieval of Day-Ahead prices from ENTSO-E API
- **30-day historical reference**: Card showing Min/Average/Max and data maturity percentage
- Price display for **yesterday**, **today**, and **tomorrow** (when available)
- Multi-day chart with price trends and **monthly average line** (selectable)
- Detailed tables with hourly prices and power bands

### Optimization Algorithm
The application implements a classification algorithm based on **historical reference (30 days)**:

1. **Historical Data Acquisition**
   On first launch, the app retrieves 30 days of historical data from the ENTSO-E API to calculate:
   - `C_min_historical`: Minimum price over the last 30 days
   - `C_max_historical`: Maximum price over the last 30 days
   - `C_avg_historical`: Average price over the last 30 days

2. **Deviation Percentage Calculation**
   ```
   %i = ((Ci - C_min_historical) / (C_max_historical - C_min_historical)) × 100
   ```
   Where `Ci` is the price at hour i, referenced to the monthly historical range.

3. **Power Band Classification**
   Classification considers both the percentage and the historical average:

   | Condition | Band | Power |
   |-----------|------|-------|
   | `%i >= 66%` | 1 (High cost) | 20% |
   | `Ci > C_avg_historical` | 2 (Above average) | 50% |
   | `%i < 33%` AND `Ci <= C_avg_historical` | 3 (Low cost) | 100% |
   | `%i >= 33%` AND `Ci <= C_avg_historical` | 2 (Medium cost) | 50% |

   **Key rule**: If the current price exceeds the monthly average, maximum power is capped at 50%, regardless of position in the min/max range.

### TCP Communication
- Automatic command sending to dView server (MES interface protocol)
- Command format: `{"impr":"all","heat":XX,"fan":XX}\n` (NDJSON)
- Configurable send interval (30-600 seconds)
- Real-time connection status monitoring

### Additional Features
- Configurable auto-refresh (1-60 minutes)
- Light/dark theme support (follows system settings)
- Responsive layout (mobile and desktop)
- Local settings persistence

## Prerequisites

- Flutter SDK ^3.7.0
- Dart SDK ^3.7.0
- ENTSO-E Security Token (free, registration required)

### Obtaining the ENTSO-E Security Token

1. Register on [ENTSO-E Transparency Platform](https://transparency.entsoe.eu/)
2. Access your profile
3. Generate a Security Token in the API section

## Installation

```bash
# Clone the repository
git clone https://github.com/Pataff/entsoe_flutter.git
cd entsoe_flutter

# Install dependencies
flutter pub get

# Run the application
flutter run
```

## Configuration

On first launch, access **Settings** to configure:

| Parameter | Description | Default |
|-----------|-------------|---------|
| Security Token | ENTSO-E API token | - |
| Domain | Market area code (e.g., `10IT-GRTN-----B` for Italy) | IT |
| Refresh Interval | Minutes between data updates | 15 |
| TCP Server IP | dView server address | - |
| TCP Port | dView server port | 5000 |
| TCP Auto Send | Enable automatic command sending | Off |
| TCP Interval | Seconds between TCP sends | 60 |

### ENTSO-E Domain Codes

| Country | Code |
|---------|------|
| Italy | `10IT-GRTN-----B` |
| Germany | `10Y1001A1001A83F` |
| France | `10YFR-RTE------C` |
| Spain | `10YES-REE------0` |
| Austria | `10YAT-APG------L` |

## Architecture

```
lib/
├── main.dart                 # Entry point and theme configuration
├── models/
│   ├── app_settings.dart     # Settings model
│   ├── connection_status.dart # Connection states
│   └── price_data.dart       # Price data models
├── providers/
│   └── app_provider.dart     # State management (Provider)
├── screens/
│   ├── dashboard_screen.dart # Main screen
│   └── settings_screen.dart  # Settings screen
├── services/
│   ├── entsoe_service.dart   # ENTSO-E API client
│   ├── price_calculator.dart # Optimization algorithm
│   ├── storage_service.dart  # Local persistence
│   └── tcp_service.dart      # TCP client for dView
└── widgets/
    ├── compact_price_table.dart    # Compact price table
    ├── connection_status_widget.dart # Connection indicator
    ├── current_hour_card.dart      # Current hour card
    ├── multi_day_chart.dart        # Multi-day chart
    └── price_chart.dart            # Single price chart
```

## Dependencies

| Package | Version | Usage |
|---------|---------|-------|
| http | ^1.2.0 | HTTP calls to ENTSO-E API |
| xml | ^6.5.0 | XML response parsing |
| provider | ^6.1.1 | State management |
| shared_preferences | ^2.2.2 | Local storage |
| fl_chart | ^0.68.0 | Charts |
| intl | ^0.19.0 | Date formatting |

## Supported Platforms

- Windows
- macOS
- Linux
- Android
- iOS
- Web

## MES Interface Protocol

The application communicates with the dView server using the MES interface protocol:

### Impr Command (Energy Reduction)
```json
{"impr":"all","heat":XX,"fan":XX}
```
- `impr`: Command identifier ("all" for all devices)
- `heat`: Heating power percentage (20, 50, 100)
- `fan`: Ventilation power percentage (20, 50, 100)

Each message is in **NDJSON** (Newline Delimited JSON) format, terminated with `\n`.

## Screenshot

The application features a dashboard with:
- Current hour info card with price and power band
- 3-day price trend chart
- Detailed tables for yesterday, today, and tomorrow
- ENTSO-E and TCP connection status indicators

## License

MIT License

## Author

Project developed for dynamic energy cost optimization based on Day-Ahead market prices.
