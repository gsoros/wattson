import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../ble/ble_service.dart';
import '../util/app_log.dart';

/// Orchestrates auto-connect on launch and periodic rescans.
///
/// On app start, reads stored MACs from [SharedPreferences], scans, and
/// connects to both preferred devices. While any slot is disconnected,
/// rescans every 30 seconds (skipping if a scan is already in progress).
class AutoConnectManager {
  AutoConnectManager(this._service) {
    _run();
  }

  /// Module logger (auto-captures caller class + file:line).
  static final _log = AppLog.logFor('AutoConnect');

  final BleService _service;
  Timer? _rescanTimer;
  bool _started = false;

  void _run() {
    if (_started) return;
    _started = true;

    // Debounce: start a short delay so the widget tree is ready.
    Future.delayed(const Duration(milliseconds: 500), _doAutoConnect);

    // Periodic rescan timer.
    _rescanTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _doAutoConnect();
    });
  }

  Future<void> _doAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final dashMac = prefs.getString('preferred_dash_mac');
    final hrmMac = prefs.getString('preferred_hrm_mac');
    final dashName = prefs.getString('preferred_dash_name');
    final hrmName = prefs.getString('preferred_hrm_name');

    if (dashMac == null && hrmMac == null) {
      _log.d('no stored MACs');
      return;
    }

    if (_service.isScanning) {
      _log.d('already scanning');
      return;
    }

    _log.d('starting scan for stored devices...');
    await _service.startScan();

    // Give the scan a moment to find devices, then connect.
    await Future.delayed(const Duration(seconds: 3));

    if (dashMac != null && !_service.dashConnected) {
      _log.d('connecting to Dash: $dashName ($dashMac)');
      await _service.connectToDash(dashMac, name: dashName);
    }
    if (hrmMac != null && !_service.hrmConnected) {
      _log.d('connecting to HRM: $hrmMac');
      await _service.connectToHrm(hrmMac, name: hrmName);
    }
  }

  void dispose() {
    _rescanTimer?.cancel();
    _rescanTimer = null;
  }
}
