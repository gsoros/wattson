# Changelog

## [1.2.0] — 2026-07-24 — Ride stats overhaul

### Added
- **Live ride stats**: Average Power, Normalized Power (WAP), and Average Cadence
  tiles appear on the main ride screen during recording.
- **Normalized Power (WAP)**: 30-second rolling average algorithm (Coggan/TrainingPeaks)
  computed live during recording and finalized at stop.
- **Intensity Factor (IF) & Training Stress Score (TSS)**: Computed from NP and
  FTP, displayed on RideDetails.
- **FTP setting**: Functional Threshold Power field on Settings page, persisted
  via SharedPreferences (default 150 W).
- **Ride FTP**: Editable FTP field on RideDetails, stored per-ride for historical
  accuracy. Editing recomputes IF/TSS.
- **Motor energy**: Total watt-hours consumed by the motor, computed at stop.
- **PAS level distribution**: New `PasLevelDistribution` table recording time
  spent at each assist level, displayed on RideDetails.
- **Collapsible RideDetails**: Metrics grouped into Ride, Performance, Movement,
  and Assistance sections with tap-to-toggle.
- **Moving/stopped time**: Elapsed time broken into moving and stopped durations.
- **Average speed & moving average speed**: Displayed on RideDetails.
- **Cadence zero-exclusion**: Average cadence now excludes zero samples
  (disconnected sensor) in both live and final computations.

### Changed
- `RecordingState` accumulators extended for live stats (power, cadence, PAS).
- `_computeRideStats` computes NP via shared `NormalizedPowerCalculator`.
- `Rides` table: added `weightedAvgPowerW`, `rideFtpW`, `motorEnergyWh` columns.
- Database schema v3: new `PasLevelDistribution` table + migration.
- Version: `1.1.0+1` → `1.2.0+1`.

### Fixed
- Average cadence no longer includes zero samples (disconnected sensor).

## [1.1.0] — 2026-07-24 — First stable release

### Added
- Multi-device BLE: Dash (CTS telemetry) + HRM (heart rate monitor) connection slots.
- Live ride screen: speed hero card, 2-column metric grid, battery SoC bar.
- Recording: start/pause/resume/stop with Drift database (rides + samples tables).
- Foreground service: wake-lock + notification for background recording.
- GPS tracking: odometry-based distance, positive-only elevation gain.
- GPX export with `share_plus` (Strava/Intervals.icu compatible).
- Ride history page with swipe gestures.
- Full-screen mode (double-tap to enter/exit).
- Device configuration dialog (hostname, Wi-Fi, BLE, battery capacity, etc. via NUS).
- Settings page with device discovery, auto-connect, and API key entry.
- Ride details page with map tab (OpenCycleMap / OSM).
- Custom launcher icon (green rounded square, white "W" + bicycle wheels).

### Changed
- Bundle ID: `app.wattson.wattson` → `org.gsoros.wattson`.
- Navigation: pure `Navigator` (removed `PageView`/`_MainShell` hybrid).
- Version: `1.0.0+1` → `1.1.0+1`.

### Fixed
- Batch state updates in device config to avoid skipped frames.
- UTF-8 encoding for BLE communication (non-ASCII round-trip).
- StreamProvider initial state via `_withInitialState` helper.
- Zero-area bounds guard in map tab.
- Crash guards around BLE operations during disconnect/reconnect.
