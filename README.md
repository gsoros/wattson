# wattson

Companion mobile app for the [OpenRideDash](https://github.com/gsoros/open-ride-dash) e-bike display.

Built with Flutter, wattson connects to the ORD Dash via BLE to display live ride telemetry, record rides with GPS, and export data — all local-first with no cloud dependency.

## Features

- **Live ride display** — real-time speed, human power, motor power, cadence, heart rate, battery SoC, PAS level, and range
- **BLE connection** — scan, pair, and connect to the ORD Dash (custom Cycling Telemetry Service) and a standard BLE heart rate monitor simultaneously
- **Ride recording** — start/pause/resume/stop with GPS tracking via foreground service; stores telemetry and location samples to a local Drift (SQLite) database
- **Ride history** — browse past rides with summary stats (duration, distance, elevation, avg/max power, avg cadence, avg HR)
- **Ride details & map** — view recorded GPS tracks on an OpenStreetMap-based map (via `flutter_map`) with zoom, pan, and attribution
- **GPX export** — export rides to GPX 1.1 with heart rate, cadence, speed, and power extensions; imports cleanly into Strava and Intervals.icu
- **Device configuration** — read/write ORD Dash settings (Wi-Fi, hostname, BLE toggle, etc.) over the Nordic UART Service (NUS)

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Material 3) |
| State management | Riverpod |
| BLE | `flutter_blue_plus` (dual-slot: Dash + HRM) |
| Location | `geolocator` |
| Background service | `flutter_foreground_task` |
| Local storage | Drift (SQLite, WAL mode) |
| Map rendering | `flutter_map` (OSM, vendor-free) |
| Export | GPX 1.1 via `share_plus` |
| Logging | `logger` (structured, per-module levels) |

## Architecture

```
┌─────────────────────────────────────────────┐
│  UI (Material 3, Riverpod)                  │  ride screen, settings, history, config
├─────────────────────────────────────────────┤
│  Providers (Riverpod)                       │  connection slots, scan results, telemetry
├─────────────────────────────────────────────┤
│  Repository (Drift / shared_preferences)    │  rides + samples DB, persistent MAC storage
├─────────────────────────────────────────────┤
│  BleService (abstract)                      │  multi-device: Dash slot + HRM slot
│   ├─ RealBleService (flutter_blue_plus)     │  scan, connect/disconnect per slot
│   └─ MockBleService (dev/simulator)         │  emits two virtual devices for testing
└─────────────────────────────────────────────┘
```

## Getting Started

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (SDK ^3.12.2)
2. Clone the repo and run:
   ```bash
   flutter pub get
   dart run build_runner build
   ```
3. Launch on a connected device or emulator:
   ```bash
   flutter run
   ```

> **Note:** The app targets Android 15+ (primary) and iOS (best-effort). A physical device with BLE is required for full functionality. The `MockBleService` can be used for development without hardware.

## Project Structure

```
lib/
├── ble/          — BleService interface, RealBleService, MockBleService
├── config/       — map tile config, app constants
├── data/         — Drift database, RecordingService
├── export/       — GPX serializer, export service
├── models/       — Telemetry, ScanResult, RecordingState
├── providers/    — Riverpod providers (telemetry, recording, connection)
├── service/      — background/foreground service glue
├── ui/           — screens (ride, settings, history, details, config)
└── util/         — helpers, extensions
```

## License

This project is licensed under the terms of the included LICENSE.