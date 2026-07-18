import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/ble_service.dart';

/// Orchestrates auto-connect on launch and periodic rescans.
///
/// On app start, reads stored MACs from [SharedPreferences], scans, and
/// connects to both preferred devices. While any slot is disconnected,
/// rescans every 30 seconds (skipping if a scan is already in progress).
class AutoConnectManager {
  AutoConnectManager(this._service) {
    _run();
  }

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
      debugPrint('[AutoConnect] no stored MACs');
      return;
    }

    if (_service.isScanning) {
      debugPrint('[AutoConnect] already scanning');
      return;
    }

    debugPrint('[AutoConnect] starting scan for stored devices...');
    await _service.startScan();

    // Give the scan a moment to find devices, then connect.
    await Future.delayed(const Duration(seconds: 3));

    if (dashMac != null && !_service.dashConnected) {
      debugPrint('[AutoConnect] connecting to Dash: $dashName ($dashMac)');
      await _service.connectToDash(dashMac, name: dashName);
    }
    if (hrmMac != null && !_service.hrmConnected) {
      debugPrint('[AutoConnect] connecting to HRM: $hrmMac');
      await _service.connectToHrm(hrmMac, name: hrmName);
    }
  }

  void dispose() {
    _rescanTimer?.cancel();
    _rescanTimer = null;
  }
}
