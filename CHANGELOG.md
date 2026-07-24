# Changelog

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
