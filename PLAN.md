# Wattson — Implementation Plan

Companion Android/iOS app for the OpenRideDash (ORD Dash) e-bike display.
Single-user, local-first. Not for app-store distribution.

## Architecture (layered, with a mockable BLE boundary)

```
┌─────────────────────────────────────────────┐
│  UI (Material 3, Riverpod)                  │  ride screen, settings, history, config
├─────────────────────────────────────────────┤
│  Providers (Riverpod)                       │  connection slots, scan results, telemetry
├─────────────────────────────────────────────┤
│  Repository (shared_preferences / Drift)    │  P1–P2: pref keys for 2 MAC addresses
│                                              │  P5+: Drift rides + samples (append-only)
├─────────────────────────────────────────────┤
│  BleService (abstract interface)            │  multi-device: Dash slot + HRM slot
│   ├─ RealBleService (flutter_blue_plus)     │   scan stream, connect/disconnect per slot
│   └─ MockBleService (dev/simulator)         │   emits two virtual devices for testing
└─────────────────────────────────────────────┘
```

`BleService` manages **two independent connection slots** — one for the ORD Dash
(Cycling Computer / CTS telemetry source) and one for a standard BLE Heart Rate
Monitor.  `MockBleService` can drive the whole app (UI, recording, export)
without any hardware.

## Firmware work (in scope — must land before Features 2 & 6) DONE

1. **Add NUS service** (`src/tasks/ble.cpp`): Nordic UART `RX` (write, 250-byte
   cap) + `TX` (read/notify). Bridge RX lines to the existing `Api::queueCommand`
   and forward `Api::Reply` out TX. Reuse `api.cpp` commands: `hostname`,
   `battery capacity`, `ble on|off|toggle|status`, `wifi ssid/password/sta/ap`,
   `restart`, `v`, `help`.
2. **Add CTS HR write characteristic** (`src/tasks/ble.h` `TODO`): a write char
   on the CTS service; on write, store HR into `state` and surface it (the
   display already has `METRIC_HEART_RATE` reserved). Unblocks Feature 2's
   push-to-Dash.

## Phase 0 — Project scaffold DONE

- `flutter create` (Android 15+ min, iOS best-effort), Material 3, Riverpod.
- `pubspec`: `flutter_blue_plus`, `geolocator`, `flutter_foreground_task`,
  `drift` + `drift_dev`, `riverpod`, `permission_handler`, `share_plus`.
- Folder layout: `lib/{ble,data,providers,ui,export,models}/`.

## Phase 1 — Multi-device BLE connection (Feature 1, revised) IN PROGRESS

`BleService` evolves from a single-device interface to a **multi-device** manager
with two independent connection slots:

| Slot | Type | Target | Identification | Telemetry source |
|---|---|---|---|---|
| **Dash** | ORD Dash (Cycling Computer) | The custom e-bike display | User picks from scan results (no filtering — show all) | CTS notify + CTS initial-value READ |
| **HRM** | Heart Rate Monitor | Standard BLE HR Service `0x180D` | User picks from scan results | HR notify → forwarded to Dash CTS HR char |

Both slots share the same scan.  The settings page shows all discovered devices
with visual hints (icon/badge) for Cycling Computer (`0x0480`) and HRM (`0x0134`)
appearances, but does not filter anything out.

### Steps

**1a. Refactor `BleService` interface**
- `connect()` → `connectDash()` / `connectHrm()`, or a single `connectDevice(DeviceId)`.
- `disconnect()` → `disconnectDash()` / `disconnectHrm()`.
- `connectionState` → `dashConnectionState` + `hrmConnectionState` streams.
- Expose `Stream<List<ScanResult>>` for live scan results consumed by the UI.
- Persistent MAC storage via `shared_preferences` (two keys: `preferred_dash_mac`,
  `preferred_hrm_mac`). Can migrate to Drift later.

**1b. Live scan results stream**
- Scan runs continuously while settings page is open, and in 30s cycles during
  auto-reconnect (skip if scan already in progress).
- `RealBleService` emits `ScanResult` objects (device ID, name, RSSI, appearance,
  manufacturer data). The UI layer filters and displays.
- On Android: request `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` + `ACCESS_FINE_LOCATION`
  before scanning (existing permission flow).

**1c. Settings page**
- Replace the Connect/Disconnect FAB with a gear icon in the app bar that opens
  the settings page.
- Settings page shows a list of discovered devices. Each row: icon (based on
  appearance), name, RSSI, MAC address, and a dynamic connect/disconnect button.
- When user presses **Connect**: save MAC to `shared_preferences`, initiate connection.
- When user presses **Disconnect**: remove MAC from `shared_preferences`, disconnect,
  trigger a rescan.
- At most one Dash and one HRM connected at a time.

**1d. Auto-connect + periodic rescan**
- On launch, read stored MACs from `shared_preferences`, scan, and connect to both.
- While either slot is disconnected, rescans every 30 seconds.
- Don't start a new scan if one is already in progress.

**1e. Bonding (unchanged from previous plan)**
- Phone enters the 6-digit passkey shown on the Dash (`BLE_HS_IO_DISPLAY_ONLY`).
- Persist bonded device; auto-reconnect on launch/drop.

**1f. Connect + subscribe (Dash, unchanged)**
- Discover CTS + NUS services.
- Subscribe to CTS notify; call `ctsChar.read()` for immediate initial value.
- Subscribe to NUS TX notify (fragmented, 2-byte length prefix).
- NUS RX write for commands; NUS TX reassembly for replies.

**1g. Connect + subscribe (HRM, new)**
- Discover HR Service `0x180D`, characteristic `0x2A37` (HR measurement notify).
- Subscribe to HRM notify. On each update, write BPM to Dash's CTS HR char
  (if Dash is connected). Also emit HR value into `Telemetry` stream.

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
- **Motor power** is derived from **CTS** voltage * current, 
  no need to use **CPS**
- **Battery %** authoritative source = CTS SoC (BAS `_batteryLevel` starts at 0;
  ignore it).
- Unified `Telemetry` model: `{speed, battV, battI, soc, range, pas,
  humanPower, motorPower, cadence, hr}`.

## Phase 3 — Live display (Feature 3)

- Ride screen: human power, motor power, cadence, speed, HR, PAS, battery SoC + V, range
- Additional fields while recording: elapsed, time-in-motion, distance, elevation gain.
- `Telemetry` stream → Riverpod → widgets.

## Phase 4 — Recording (Feature 4)

- Start/stop/pause session. `flutter_foreground_task` holds wake-lock +
  persistent notification (Android 14 `location` type) while the **main isolate**
  keeps the `flutter_blue_plus` connection (per decision).
- `geolocator` GPS stream + permission handling; `elevation gain` = GPS altitude 
  gain (climbing a 100m tall hill 3 times = 300m gain, only positive vertical delta is recorded).
- Drift append-only `samples` (1 row / CTS tick). GPS joined by nearest-timestamp
  interpolation into the same row.
- `rides` summary computed at stop.

## Phase 5 — Data layer (Drift schema, refined)

```sql
rides(id PK, start_time, end_time, time_in_motion, distance,
      elevation_gain, avg_human_power, max_human_power, avg_motor_power,
      avg_cadence, avg_hr, assist_ratio, notes)
samples(ride_id FK INDEX, ts, lat, lon, elevation, speed, human_power, motor_power,
        cadence, pas_level, hr, battery_v, battery_a, soc, range)
```

- `assist_ratio` = motor / (human + motor). `time_in_motion` = Σ ticks where
  speed > threshold.
- WAL mode (survives hard kill mid-write).

## Phase 6 — Export (Feature 5, GPX + CSV)

- Generated on demand from DB rows (not during recording).
- **GPX** with `<gpxtpx:TrackPointExtension>` carrying hr/cadence/power
  (Strava-compatible).
- **CSV** flat dump of `samples`.
- Manual `share_plus` OS sheet; no cloud/accounts.

## Phase 7 — Device config (Feature 6)

- Via NUS → existing text API. UI forms for: Wi-Fi STA SSID/password + STA/AP
  toggle, hostname, battery capacity, BLE on/off. Send command, parse
  `Api::Reply` `Code`/`data`.
- Note: some commands (`ble`, `wifi mode`) trigger **device reboot** — handle
  gracefully (auto-reconnect).

## Phase 8 — Permissions & platform

- Android: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`,
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`. iOS:
  `NSBluetoothAlwaysUsageDescription`, location keys, background BLE mode
  (best-effort).

## Phase 9 — Testing

- `MockBleService` drives UI/recording/export without hardware.
- Unit tests: `CtsParser` (every field, signed PAS, version mismatch), Drift
  aggregations, GPX/CSV serializers.
- Widget tests for ride + config screens.

## Milestones

| M | Deliverable |
|---|---|
| M0 | Scaffold + `BleService` interface + `MockBleService` | **DONE** |
| M1 | Single Dash connection + CTS parser (live values) | **DONE** |
| M2 | Multi-device BLE (Dash + HRM) + settings page + auto-connect | **IN PROGRESS** |
| M3 | Live ride screen |
| M4 | Recording + Drift + foreground service |
| M5 | GPX/CSV export |
| M6 | NUS + device config UI |
| M7 | Permissions, iOS pass, tests, polish |

**Firmware dependencies:** M1 needs NUS only for config (M6); M2's push-to-Dash
needs the HR write char. Both firmware tasks are DONE.
