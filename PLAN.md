# Wattson — Implementation Plan

Companion Android/iOS app for the OpenRideDash (ORD Dash) e-bike display.
Single-user, local-first. Not for app-store distribution.

## Architecture (layered, with a mockable BLE boundary)

```
┌─────────────────────────────────────────────┐
│  UI (Material 3, Riverpod)                   │  ride screen, history, config, BLE status
├─────────────────────────────────────────────┤
│  Providers (Riverpod)                         │  connection, telemetry stream, recording session
├─────────────────────────────────────────────┤
│  Repository (Drift / SQLite WAL)              │  rides + samples, append-only
├─────────────────────────────────────────────┤
│  BleService (abstract interface)              │  connect/scan/notify/subscribe
│   ├─ RealBleService (flutter_blue_plus)       │
│   └─ MockBleService (dev/simulator)           │  emits CTS/CPS/CSC/BAS/HR without hardware
└─────────────────────────────────────────────┘
```

`BleService` is an abstract class so `MockBleService` can drive the whole app
(UI, recording, export) without a Dash unit.

## Firmware work (in scope — must land before Features 2 & 6)

1. **Add NUS service** (`src/tasks/ble.cpp`): Nordic UART `RX` (write, 250-byte
   cap) + `TX` (read/notify). Bridge RX lines to the existing `Api::queueCommand`
   and forward `Api::Reply` out TX. Reuse `api.cpp` commands: `hostname`,
   `battery capacity`, `ble on|off|toggle|status`, `wifi ssid/password/sta/ap`,
   `restart`, `v`, `help`.
2. **Add CTS HR write characteristic** (`src/tasks/ble.h` `TODO`): a write char
   on the CTS service; on write, store HR into `state` and surface it (the
   display already has `METRIC_HEART_RATE` reserved). Unblocks Feature 2's
   push-to-Dash.

## Phase 0 — Project scaffold

- `flutter create` (Android 15+ min, iOS best-effort), Material 3, Riverpod.
- `pubspec`: `flutter_blue_plus`, `geolocator`, `flutter_foreground_task`,
  `drift` + `drift_dev`, `riverpod`, `permission_handler`, `share_plus`.
- Folder layout: `lib/{ble,data,providers,ui,export,models}/`.

## Phase 1 — BLE connection & pairing (Feature 1)

- `BleService.scan()` filters by **hostname** (CTS 128-bit UUID isn't advertised;
  advertising carries only CSC+CPS + name). Match `state.hostname()` (default
  `ORD Dash`).
- Bonding: implement `passkeyRequired` callback — **phone enters** the 6-digit
  passkey shown on the Dash (`BLE_HS_IO_DISPLAY_ONLY`). Persist bonded device;
  auto-reconnect on launch/drop.
- On connect: discover services, subscribe to **CTS notify** + **NUS TX notify**.
- Connection status UI: enabled / disabled / searching / connected / lost.

## Phase 2 — Telemetry parsing (the exact contract)

`CtsParser` decodes the **14-byte little-endian** payload (`version` byte `0x01`):

| byte | field | type |
|---|---|---|
| 0 | version | uint8 (0x01) |
| 1–2 | speed | uint16, km/h ×100 |
| 3–4 | batt V | uint16, V ×100 |
| 5–6 | batt I | uint16, A ×100 (**unsigned** — no regen) |
| 7 | SoC | uint8, % |
| 8–9 | range | uint16, km ×100 |
| 10 | PAS | int8 (−1 walk … 5) |
| 11–12 | human power | uint16, W ×10 |
| 13 | cadence | uint8, RPM |

- Forward-compat: ignore trailing bytes if `payload.length > 14`; reject/flag
  unknown `version`.
- **Motor power** comes from **CPS** `0x2A63` (uint16 instantaneous power,
  change-gated) — not CTS.
- **Battery %** authoritative source = CTS SoC (BAS `_batteryLevel` starts at 0;
  ignore it).
- Unified `Telemetry` model: `{speed, battV, battI, soc, range, pas,
  humanPower, motorPower, cadence, hr}`.

## Phase 3 — HRM (Feature 2)

- Scan/connect standard **HR Service `0x180D`**; phone is central to both Dash
  + HRM.
- Record HR locally; on each HR update, **write** to the new CTS HR char
  (Phase 0 firmware).

## Phase 4 — Live display (Feature 3)

- M3 ride screen: human power, motor power, cadence, speed, HR, elapsed,
  time-in-motion, distance.
- `Telemetry` stream → Riverpod → widgets.

## Phase 5 — Recording (Feature 4)

- Start/stop/pause session. `flutter_foreground_task` holds wake-lock +
  persistent notification (Android 14 `location` type) while the **main isolate**
  keeps the `flutter_blue_plus` connection (per decision).
- `geolocator` GPS stream + permission handling; `elevation` = GPS altitude.
- Drift append-only `samples` (1 row / CTS tick). GPS joined by nearest-timestamp
  interpolation into the same row (or a separate `gps_points` table if cleaner —
  recommend interpolation into `samples`).
- `rides` summary computed at stop.

## Phase 6 — Data layer (Drift schema, refined)

```sql
rides(id PK, start_time, end_time, time_in_motion, distance,
      elevation, avg_human_power, max_human_power, avg_motor_power,
      avg_cadence, avg_hr, assist_ratio, notes)
samples(ride_id FK INDEX, ts, lat, lon, speed, human_power, motor_power,
        cadence, pas_level, hr, battery_v, battery_a, soc, range)
```

- `assist_ratio` = motor / (human + motor). `time_in_motion` = Σ ticks where
  speed > threshold.
- WAL mode (survives hard kill mid-write).

## Phase 7 — Export (Feature 5, GPX + CSV)

- Generated on demand from DB rows (not during recording).
- **GPX** with `<gpxtpx:TrackPointExtension>` carrying hr/cadence/power
  (Strava-compatible).
- **CSV** flat dump of `samples`.
- Manual `share_plus` OS sheet; no cloud/accounts.

## Phase 8 — Device config (Feature 6)

- Via NUS → existing text API. UI forms for: Wi-Fi STA SSID/password + STA/AP
  toggle, hostname, battery capacity, BLE on/off. Send command, parse
  `Api::Reply` `Code`/`data`.
- Note: some commands (`ble`, `wifi mode`) trigger **device reboot** — handle
  gracefully (auto-reconnect).

## Phase 9 — Permissions & platform

- Android: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`,
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`. iOS:
  `NSBluetoothAlwaysUsageDescription`, location keys, background BLE mode
  (best-effort).

## Phase 10 — Testing

- `MockBleService` drives UI/recording/export without hardware.
- Unit tests: `CtsParser` (every field, signed PAS, version mismatch), Drift
  aggregations, GPX/CSV serializers.
- Widget tests for ride + config screens.

## Milestones

| M | Deliverable |
|---|---|
| M0 | Scaffold + `BleService` interface + `MockBleService` |
| M1 | BLE connect/pair/subscribe + CTS parser (live values) |
| M2 | HRM + CPS motor power + live screen |
| M3 | Recording + Drift + foreground service |
| M4 | GPX/CSV export |
| M5 | NUS + device config UI |
| M6 | Permissions, iOS pass, tests, polish |

**Firmware dependencies:** M1 needs NUS only for config (M5); M2's push-to-Dash
needs the HR write char. Both firmware tasks should start in parallel with M0.
