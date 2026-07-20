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

## Phase 1 — Multi-device BLE connection (Feature 1, revised) DONE

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

## Phase 3 — Live display (Feature 3) DONE

- Ride screen: human power, motor power, cadence, speed, HR, PAS, battery SoC + V, range.
  Layout: speed hero card (full-width, large displayMedium), secondary metrics in a 2-column
  Wrap grid (MetricTile: label/value/unit stacked), battery tile with SoC progress bar + voltage.
- Additional fields while recording: elapsed, distance, elevation gain shown in a TripStatsTile.
- Recording controls pinned to bottom: Record FAB (disabled/greyed when no device connected),
  Pause/Stop during recording, Resume/Stop when paused. Stop/pause always enabled during
  active session regardless of connection state.
- `Telemetry` stream → `telemetryProvider` → `_RideContent` widget.

## Phase 4 — Recording (Feature 4) DONE

- `RecordingService` (`lib/data/recording_service.dart`): manages start/pause/resume/stop.
  Listens to telemetry stream + GPS (Geolocator.getPositionStream, high accuracy). On every
  CTS tick while recording, writes a `Sample` row to Drift and accumulates elapsed time,
  distance (odometry from speed × tick), and elevation gain (positive-only GPS altitude delta).
- `RecordingState` / `RecordingStatus`: immutable snapshot for UI (elapsed, distance, climb, rideId).
- `RecordingService.stateStream` yields current state via `_withInitialState` helper in the
  provider so Riverpod's StreamProvider never starts in `loading`.
- GPS started on construction so first fix is ready when user hits Record.
- Elevation: only positive deltas accumulated (climbing 100m hill 3 times = 300m gain).

## Phase 5 — Data layer (Drift schema, refined) DONE

```sql
rides(id PK, start_time, end_time, time_in_motion, distance,
      elevation_gain, avg_human_power, max_human_power, avg_motor_power,
      avg_cadence, avg_hr, assist_ratio, notes)
samples(ride_id FK INDEX, ts, lat, lon, elevation, speed, human_power, motor_power,
        cadence, pas_level, hr, battery_v, battery_a, soc, range)
```

- `AppDatabase` in `lib/data/database.dart`: Drift with WAL mode (NativeDatabase).
- `drift_dev` + `build_runner` in dev_dependencies for codegen.
- `databaseProvider` singleton in `recording_provider.dart`.
- `recordingServiceProvider` wires `RecordingService(database, bleService.telemetry)`.
- `recordingStateProvider` = `StreamProvider<RecordingState>` with initial-state yield.

## Phase 6 — Export (Feature 5, GPX + CSV)

- Generated on demand from DB rows (not during recording).
- **GPX** — DONE. `lib/export/gpx_serializer.dart` builds a GPX 1.1 doc with
  `<gpxtpx:TrackPointExtension>` (Garmin v1 namespace) carrying `hr`, `cad`,
  `distance` (cumulative, from speed×dt), `speed` (m/s), and `watts` = **human
  power**. Motor power has no standard GPX field, so it is written as a custom
  `<wattson:motorWatts>` element (ignored by Strava/Garmin, usable by the in-app
  Graphs tab and configurable tools). `lib/export/export_service.dart` writes the
  GPX to the temp dir and opens the OS sheet via `share_plus`. Verified: imports
  cleanly into both **Strava** and **Intervals.icu**.
- **CSV** flat dump of `samples` — DEFERRED to a later phase (not needed yet;
  GPX covers the primary export path).
- Manual `share_plus` OS sheet; no cloud/accounts.

## Phase 6b — Ride details: Map tab DONE

- `lib/ui/ride_details_page.dart` shows a 3-tab view: Details, **Map**, Graphs.
- `lib/ui/ride_map_tab.dart` renders the recorded GPS track with `flutter_map`
  (v8, OSM-based, vendor-free): a `PolylineLayer` over a `TileLayer`, with
  zoom/pan via `InteractionOptions(flags: InteractiveFlag.all)` and a
  `RichAttributionWidget` (bottom-right).
- `lib/config/map_config.dart` centralizes tile sources: **OpenCycleMap**
  (Thunderforest `cycle` style) when a free API key is set, otherwise an
  **OpenStreetMap** no-key fallback. Both require a valid `userAgentPackageName`
  (`app.wattson.wattson`). Attribution string switches accordingly.
- The Thunderforest API key is entered on the **Settings** page
  (`_ApiKeyCard`), persisted via `SharedPreferences` (`thunderforest_api_key`),
  loaded at startup in `main` via `MapConfig.load()`, and saved (debounced)
  via `MapConfig.setApiKey`.
- Samples are loaded from Drift (`samples` where `ride_id` = ride id) in
  `initState` and passed to the tab; rides without GPS show a placeholder.
- **Zero-area bounds guard:** if all valid fixes share one coordinate, the map
  centers on that point at a fixed zoom (instead of `CameraFit.bounds`, which
  would compute a non-finite zoom and crash). `CameraFit.bounds` also gets a
  `maxZoom` cap as a safety net.

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
| M2 | Multi-device BLE (Dash + HRM) + settings page + auto-connect | **DONE** |
| M3 | Live display (ride screen, 2-column layout, battery bar) | **DONE** |
| M4 | Recording (Drift DB, RecordingService, start/pause/stop, GPS) | **DONE** |
| M5 | Foreground service + background recording | **DONE** |
| M6 | Export (GPX + share_plus; CSV deferred) | **GPX DONE** |
| M6b | Ride details Map tab (flutter_map, OpenCycleMap/OSM) | **DONE** |
| M7 | Device config (Wi-Fi, hostname, etc. via NUS) | |
| M8 | Permissions, iOS pass, tests, polish |

**Firmware dependencies:** M1 needs NUS only for config (M6); M2's push-to-Dash
needs the HR write char. Both firmware tasks are DONE.
