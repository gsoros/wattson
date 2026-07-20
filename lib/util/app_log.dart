import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// On-device append-only diagnostic log used to capture crash/diagnostic output
/// across sessions (e.g. to reproduce the out-of-BLE-range crash from the
/// 2026-07-20 ride).
///
/// [init] redirects every [debugPrint] call to a timestamped file in the app's
/// documents directory, so the existing `debugPrint(...)` call sites throughout
/// the app are captured automatically with no changes. Uncaught Flutter and
/// async errors are also logged. The file can be shared from Settings via
/// [share].
class AppLog {
  AppLog._();

  static File? _file;
  static final List<String> _queue = [];
  static bool _writing = false;
  static const int _maxBytes = 1024 * 1024; // Rotate at 1 MB.

  /// Initializes the log file, redirects [debugPrint] to it, and installs
  /// handlers that log uncaught Flutter / async errors. Call once from [main]
  /// after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/wattson.log');

    // Rotate if the log has grown too large to avoid unbounded growth.
    if (_file!.existsSync() && _file!.lengthSync() > _maxBytes) {
      _file!.writeAsStringSync('');
    }

    // Keep the original console output and additionally append to the file.
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      original(message, wrapWidth: wrapWidth);
      _append(message ?? '');
    };

    // Log framework errors (e.g. during build/layout).
    FlutterError.onError = (details) {
      _append('FlutterError: ${details.exception}\n${details.stack}');
    };

    // Log uncaught async errors outside the Flutter framework.
    PlatformDispatcher.instance.onError = (error, stack) {
      _append('Uncaught: $error\n$stack');
      return true;
    };
  }

  /// Appends a timestamped line to the log (used by the [debugPrint] redirect
  /// and the error handlers). Safe to call from anywhere.
  static void log(String message) => _append(message);

  static void _append(String line) {
    final ts = DateTime.now().toIso8601String();
    _queue.add('$ts  $line\n');
    _flush();
  }

  static void _flush() {
    if (_writing || _file == null) return;
    _writing = true;
    final batch = _queue.join();
    _queue.clear();
    // File IO is tiny; defer to a microtask so callers aren't blocked.
    Future.microtask(() async {
      try {
        await _file!.writeAsString(batch, mode: FileMode.append);
      } catch (_) {
        // Best-effort: ignore write failures (e.g. storage unavailable).
      } finally {
        _writing = false;
        if (_queue.isNotEmpty) _flush();
      }
    });
  }

  /// Shares the current log file via the OS share sheet so it can be sent for
  /// analysis (e.g. after a crash). No-op if the file does not exist.
  static Future<void> share() async {
    final f = _file;
    if (f == null || !f.existsSync()) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, name: 'wattson.log', mimeType: 'text/plain')],
        subject: 'Wattson diagnostic log',
        text: 'Wattson diagnostic log',
      ),
    );
  }
}
