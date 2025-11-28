# ENTSO-E Energy Price Monitor

A Flutter application for monitoring and optimizing energy costs based on Day-Ahead prices from the ENTSO-E (European Network of Transmission System Operators for Electricity) platform.

## Live Demo

**[Try the Web App](https://pataff.github.io/entsoe_flutter/)**

## Description

The application retrieves electricity prices from the ENTSO-E Transparency Platform and automatically calculates optimal power setpoints using a **quantile-based non-linear algorithm**. Data is then sent via TCP to external control systems (e.g., dView) for dynamic consumption optimization.

## Features

### Price Monitoring
- Automatic retrieval of Day-Ahead prices from ENTSO-E API
- **Configurable historical reference**: 1 month, 3 months, 6 months, or 1 year
- Historical reference card showing Min/Average/Max and data maturity percentage
- Price display for **yesterday**, **today**, and **tomorrow** (when available)
- Multi-day chart with price trends and **historical average line** (selectable)
- **Historical Analysis screen** with monthly trend charts
- Detailed tables with hourly prices and power setpoints

### Smart Caching System
- **Local cache** for historical price data (1 year) - fast app startup after first load
- **Incremental updates**: Only fetches new days, removes old ones (FIFO)
- Cache persists between app sessions
- Automatic cache invalidation when domain changes

### Quantile-Based Non-Linear Power Modulation Algorithm

The application implements an advanced **quantile-based non-linear algorithm** for optimal power control:

#### Algorithm Parameters (Configurable in Settings)

| Parameter | Description | Default |
|-----------|-------------|---------|
| Low Percentile | Defines "cheap" price threshold | 20% |
| High Percentile | Defines "expensive" price threshold | 80% |
| Min Reduction | Power reduction at low prices | 0% |
| Max Reduction | Power reduction at high prices | 90% |
| Non-linear Exponent | Curve aggressiveness (1=linear, 2=quadratic) | 2.0 |

#### Calculation Steps

1. **Calculate Percentile Thresholds**
   Using historical data from the selected period:
   - `P_low` = price at Low Percentile (e.g., 20th percentile)
   - `P_high` = price at High Percentile (e.g., 80th percentile)

2. **Normalize Current Price**
   ```
   β = (Price - P_low) / (P_high - P_low)
   β = clamp(β, 0, 1)
   ```

3. **Apply Non-Linear Transformation**
   ```
   β_nl = β^n    (where n = exponent)
   ```

4. **Calculate Power Reduction**
   ```
   Reduction% = R_min + β_nl × (R_max - R_min)
   ```

5. **Calculate Power Setpoint**
   ```
   Power% = 100% - Reduction%
   ```

#### Example
With default settings (P_low=50, P_high=150 EUR/MWh, exponent=2.0, max reduction=90%):
- Price = 100 EUR/MWh
- β = (100-50)/(150-50) = 0.5
- β_nl = 0.5² = 0.25
- Reduction = 0.25 × 90% = 22.5%
- **Power Setpoint = 77.5%**

#### Power Bands (Visual Indicators)

| Band | Power Range | Color | Meaning |
|------|-------------|-------|---------|
| 3 | ≥ 80% | Green | Low cost - high power |
| 2 | 40-79% | Orange | Medium cost - reduced power |
| 1 | < 40% | Red | High cost - minimum power |

### Help System
- Built-in **Help screen** with comprehensive algorithm documentation
- Step-by-step explanation of calculations
- Parameter descriptions with examples
- Accessible from Settings (? icon)

### TCP Communication
- Automatic command sending to dView server (MES interface protocol)
- Command format: `{"impr":"all","heat":XX,"fan":XX}\n` (NDJSON)
- Configurable send interval (30-600 seconds, default **5 minutes** for smooth ramp control)
- Real-time connection status monitoring

### Additional Features
- Configurable auto-refresh (15 min - 6 hours)
- **Light/dark theme support** with proper contrast
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

### Build for Web
```bash
flutter build web
# Output in build/web/
```

## Configuration

On first launch, access **Settings** to configure:

### Basic Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| Security Token | ENTSO-E API token | - |
| Domain | Market area code | IT |
| Refresh Interval | Data update frequency | 15 min |
| Historical Period | Period for threshold calculation | 3 months |

### Power Algorithm Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| Low Percentile | "Cheap" threshold (5-45%) | 20% |
| High Percentile | "Expensive" threshold (55-95%) | 80% |
| Min Reduction | Reduction at low prices (0-100%) | 0% |
| Max Reduction | Reduction at high prices (0-100%) | 90% |
| Non-linear Exponent | Curve shape (1.0-5.0) | 2.0 |

### TCP Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| TCP Server IP | dView server address | - |
| TCP Port | dView server port | 5000 |
| TCP Auto Send | Enable automatic sending | Off |
| TCP Interval | Seconds between sends | 300 (5 min) |

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
│   ├── app_settings.dart     # Settings model with algorithm params
│   ├── connection_status.dart # Connection states
│   └── price_data.dart       # Price data models
├── providers/
│   └── app_provider.dart     # State management (Provider)
├── screens/
│   ├── dashboard_screen.dart # Main dashboard
│   ├── settings_screen.dart  # Settings with algorithm config
│   ├── historical_screen.dart # Historical analysis
│   └── help_screen.dart      # Algorithm documentation
├── services/
│   ├── entsoe_service.dart   # ENTSO-E API + cache + percentiles
│   ├── price_calculator.dart # Quantile-based algorithm
│   ├── storage_service.dart  # Local persistence
│   └── tcp_service.dart      # TCP client for dView
└── widgets/
    ├── compact_price_table.dart      # Compact price table
    ├── connection_status_widget.dart # Connection indicator
    ├── current_hour_card.dart        # Current hour info
    ├── historical_trend_chart.dart   # Monthly trend chart
    ├── multi_day_chart.dart          # Multi-day price chart
    └── price_chart.dart              # Single day chart
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
- **Web** ([Live Demo](https://pataff.github.io/entsoe_flutter/))

## MES Interface Protocol

The application communicates with the dView server using the MES interface protocol:

### Impr Command (Energy Reduction)
```json
{"impr":"all","heat":XX,"fan":XX}
```
- `impr`: Command identifier ("all" for all devices)
- `heat`: Heating power percentage (continuous 0-100%)
- `fan`: Ventilation power percentage (continuous 0-100%)

Each message is in **NDJSON** (Newline Delimited JSON) format, terminated with `\n`.

## Screenshots

The application features:
- **Dashboard** with current hour info, power band indicator, and price charts
- **3-day price trend** chart with optional historical average line
- **Detailed tables** for yesterday, today, and tomorrow
- **Historical Analysis** screen with monthly trends
- **Settings** with full algorithm configuration
- **Help** screen with comprehensive documentation

## License

MIT License

## Author

Project developed for dynamic energy cost optimization based on Day-Ahead market prices.
