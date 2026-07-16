## Wattson — Project Spec

### Purpose
Companion Android/iOS app for the [OpenRideDash](https://github.com/gsoros/open-ride-dash) e-bike display (ESP32-C3, BLE GATT: CSC, CPS, BAS, DIS, custom CTS, NUS). Connects to a single paired ORD Dash unit to record ride data, display live telemetry, and configure device parameters. Single-user, local-first. Not intended for app store distribution.

### Data source — CTS payload (custom telemetry, notify @ 1Hz, change-gated)
version, speed (km/h), battery voltage (V), battery current (A), state of charge (%), range (km), PAS level (-1 to 5), human power (W), cadence (RPM)

Standard **CSC** (wheel/crank revolutions), **CPS** (human power, W), **BAS** (battery %) if necessary.

**NUS** for accessing device parameters. 

### Priority-ordered feature list

**1. BLE connection & pairing**
- BLE status UI (enabled / disabled)
- Scan/connect to ORD Dash via BLE, handle MITM passkey bonding
- Persist bonded device, auto-reconnect on launch / connection drop
- Connection status UI (connected / searching / lost)
- Discover services on connect
- Subscribe to CTS and NUS

**2. HRM connection**
- Scan/connect to a standard BLE Heart Rate Service (0x180D) strap
- Phone acts as central to both ORD Dash and HRM simultaneously
- Write HR value to ORD Dash's CTS heart rate char on each update
- Record HR alongside other telemetry

**3. Live ride data display**
- Real-time: human power, motor power, cadence, speed, HR
- Basic ride screen: current values, elapsed time, time in motion, distance

**4. Ride recording**
- Start/stop/pause session
- Location: `geolocator` for GPS stream + permission handling
- Foreground service: `flutter_foreground_task` — persistent notification, Android 14+ foreground service type `location`, keeps process alive during recording
- Storage: local DB (see below), append-only inserts, no in-place edits needed
- Ride history list: duration, distance, avg/max power, avg cadence, avg HR

**5. Data export**
- GPX/FIT/CSV generated on demand from DB rows at export time (not during recording)
- Special Strava compatibility mode: export to Strava's non-standard GPX format
- Manual share via OS share sheet — no cloud, no accounts

**6. Device configuration**
- Read/write device-side settings exposed by ORD Dash (Wi-Fi STA+AP configuration, hostname, pages. Later: calibration, display units, UI theme, etc.)

### Explicitly out of scope
- Cloud sync / accounts / multi-device
- Map display, graphs, fancy graphics (v1)
- Training load metrics (TSS/CTL/ATL)
- OTA trigger from app (use WiFi STA/AP toggle instead)

### Tech stack
- **Framework:** Flutter, latest stable
- **Target:** Android 15+ primary, iOS secondary/best-effort
- **BLE:** `flutter_blue_plus`
- **Location:** `geolocator`
- **Background/foreground service:** `flutter_foreground_task`
- **Local storage:** SQLite via Drift (WAL mode — survives hard kill mid-write, which plain GPX-file writing does not)
- **State management:** Riverpod
- **UI:** Material 3

### DB schema (rough)
- `rides`: id, start_time, end_time, time_in_motion, distance, elevation, avg_power, max_power, avg_cadence, avg_hr, assist_ratio, notes
- `samples`: ride_id, timestamp, lat, lon, speed, human_power, motor_power, cadence, pas_level, hr, battery_v, battery_a, soc, range

Insert-only, one row per sample tick.