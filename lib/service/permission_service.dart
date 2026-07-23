import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../util/app_log.dart';

/// Centralizes permission requests and serializes them so concurrent
/// calls from different services don't race.
///
/// All public methods are guarded by an internal [AsyncLock] — callers
/// never need to worry about synchronisation.
class PermissionService {
  PermissionService._();

  static final PermissionService _instance = PermissionService._();

  /// Singleton instance shared across the app.
  static PermissionService get instance => _instance;

  static final _log = AppLog.logFor('PermissionService');

  /// Async lock to prevent concurrent permission requests.
  final AsyncLock _lock = AsyncLock();

  /// Request BLE scan + connect permissions (Android only).
  Future<bool> requestBle() => _lock.synchronize(_requestBle);

  /// Request location permissions (location, locationAlways, locationWhenInUse).
  Future<bool> requestLocation() => _lock.synchronize(_requestLocation);

  /// Request notification permission.
  Future<bool> requestNotification() => _lock.synchronize(_requestNotification);

  /// Request ignore battery optimizations permission (Android only).
  Future<bool> requestIgnoreBatteryOptimizations() => _lock.synchronize(_requestIgnoreBatteryOptimizations);

  /// Request all permissions needed for ride recording
  /// (location + notification + battery).
  Future<void> requestAllRecording() => _lock.synchronize(_requestAllRecording);

  // -------------------------------------------------------------------------
  // Private implementations
  // -------------------------------------------------------------------------

  Future<bool> _requestBle() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;

    final bleResult = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    final bleGranted = bleResult[Permission.bluetoothScan]?.isGranted == true && bleResult[Permission.bluetoothConnect]?.isGranted == true;
    if (!bleGranted) {
      _log.w('BLUETOOTH_SCAN/CONNECT not granted');
      return false;
    }

    if (await Permission.locationWhenInUse.status.isDenied == true) {
      _log.d('requesting locationWhenInUse');
      await Permission.locationWhenInUse.request();
    }

    return true;
  }

  Future<bool> _requestLocation() async {
    final locationResult = await [Permission.location].request();
    final locationGranted = locationResult[Permission.location]?.isGranted == true;
    if (!locationGranted) {
      _log.w('LOCATION not granted');
      return false;
    }

    final locationAlwaysResult = await [Permission.locationAlways].request();
    final locationAlwaysGranted = locationAlwaysResult[Permission.locationAlways]?.isGranted == true;
    if (!locationAlwaysGranted) {
      _log.w('LOCATION_ALWAYS not granted');
    }

    final locationWhenInUseResult = await [Permission.locationWhenInUse].request();
    final locationWhenInUseGranted = locationWhenInUseResult[Permission.locationWhenInUse]?.isGranted == true;
    if (!locationWhenInUseGranted) {
      _log.w('LOCATION_WHEN_IN_USE not granted');
    }

    return true;
  }

  Future<bool> _requestNotification() async {
    final r = await [Permission.notification].request();
    final g = r[Permission.notification]?.isGranted == true;
    if (!g) {
      _log.w('NOTIFICATION not granted');
      return false;
    }
    return true;
  }

  Future<bool> _requestIgnoreBatteryOptimizations() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final r = await [Permission.ignoreBatteryOptimizations].request();
    final g = r[Permission.ignoreBatteryOptimizations]?.isGranted == true;
    if (!g) {
      _log.w('IGNORE_BATTERY_OPTIMIZATIONS not granted');
      return false;
    }
    return true;
  }

  Future<void> _requestAllRecording() async {
    await _requestLocation();
    await _requestNotification();
    await _requestIgnoreBatteryOptimizations();
  }
}

/// Ensures only one async operation runs at a time.
///
/// Subsequent calls to [synchronize] are queued and executed in order.
class AsyncLock {
  Future<void>? _last;

  Future<T> synchronize<T>(Future<T> Function() fn) async {
    final prev = _last;
    final completer = Completer<void>();
    _last = completer.future;

    if (prev != null) {
      await prev;
    }

    try {
      return await fn();
    } finally {
      completer.complete();
    }
  }
}
