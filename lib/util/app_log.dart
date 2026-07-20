import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Lightweight, structured on-device logging used to capture crash/diagnostic
/// output across sessions (e.g. to reproduce the out-of-BLE-range crash from
/// the 2026-07-20 ride).
///
/// Built on the `logger` package:
/// - every log line automatically includes the **caller class + file:line**
///   (parsed from the stack trace by [_CompactPrinter]);
/// - **per-module levels** via [AppLog.moduleLevels] — each module gets its own
///   [Logger] with its own [Level];
/// - output goes to both the console and a persistent file (`wattson.log` in
///   the app's documents dir), which is shared from Settings via [AppLog.share].
///
/// Get a module logger with [logFor]:
/// ```dart
/// logFor('RealBle').d('scanning started');
/// logFor('RecordingService').e('crash', error: e, stackTrace: st);
/// ```
class AppLog {
  AppLog._();

  static const int _maxBytes = 1024 * 1024; // Rotate at 1 MB.
  static File? _file;
  static late final AppLogFileOutput _fileOutput;
  static final Map<String, Logger> _loggers = {};

  /// Default level applied to module loggers that have no explicit entry in
  /// [moduleLevels].
  static Level defaultLevel = Level.debug;

  /// Per-module log levels. Set a module's level to gate its verbosity, e.g.
  /// `AppLog.moduleLevels['RealBle'] = Level.trace;`
  static final Map<String, Level> moduleLevels = {};

  /// Initializes the log file and installs handlers that route uncaught
  /// Flutter / async errors into the same log. Call once from [main] after
  /// [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/wattson.log');
    _fileOutput = AppLogFileOutput(_file!);
    // Pre-initialize the shared sink so the first logger doesn't race.
    await _fileOutput.init();

    // Uncaught framework errors (build/layout/etc.).
    FlutterError.onError = (details) {
      logFor('Flutter').e('FlutterError: ${details.exception}', error: details.exception, stackTrace: details.stack);
    };

    // Uncaught async errors outside the Flutter framework.
    PlatformDispatcher.instance.onError = (error, stack) {
      logFor('Uncaught').e('$error', error: error, stackTrace: stack);
      return true;
    };
  }

  /// Returns (and caches) a [Logger] for [module], configured with the shared
  /// file+console output and the module's level from [moduleLevels].
  static Logger logFor(String module) {
    return _loggers.putIfAbsent(module, () {
      final level = moduleLevels[module] ?? defaultLevel;
      return Logger(level: level, filter: ProductionFilter(), printer: _CompactPrinter(module), output: MultiOutput([ConsoleOutput(), _fileOutput]));
    });
  }

  /// Shares the current log file via the OS share sheet. No-op if absent.
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

/// Writes log lines to the persistent file, prepending an ISO timestamp.
///
/// [init] is idempotent so it can be safely shared across every module
/// logger's [MultiOutput] without re-opening the sink.
class AppLogFileOutput extends LogOutput {
  AppLogFileOutput(this._file);
  final File _file;
  IOSink? _sink;

  @override
  Future<void> init() async {
    if (_sink != null) return; // Idempotent: shared across module loggers.
    if (_file.existsSync() && _file.lengthSync() > AppLog._maxBytes) {
      _file.writeAsStringSync('');
    }
    _sink = _file.openWrite(mode: FileMode.append);
  }

  @override
  void output(OutputEvent event) {
    final ts = event.origin.time.toIso8601String();
    _sink?.writeAll(event.lines.map((l) => '$ts  $l'), '\n');
    _sink?.writeln();
  }

  @override
  Future<void> destroy() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}

/// Compact single-line printer that tags each line with the module and the
/// caller's `Class.method (file:line)`, parsed from the stack trace.
class _CompactPrinter extends LogPrinter {
  _CompactPrinter(this.module);
  final String module;

  static final _frameRegex = RegExp(r'#\d+\s+(\S+)\s+\((.+?):\d+:\d+\)');

  @override
  List<String> log(LogEvent event) {
    final caller = _callerFrame();
    final loc = caller != null ? ' (${caller.method} @ ${caller.file}:${caller.line})' : '';
    final msg = _stringify(event.message);
    final err = event.error != null ? '\n${event.error}' : '';
    final st = (event.stackTrace != null && event.error != null) ? '\n${event.stackTrace}' : '';
    return ['${_tag(event.level)} [$module]$loc $msg$err$st'];
  }

  String _tag(Level level) {
    switch (level) {
      case Level.trace:
        return 'TRACE';
      case Level.debug:
        return 'DEBUG';
      case Level.info:
        return 'INFO ';
      case Level.warning:
        return 'WARN ';
      case Level.error:
        return 'ERROR';
      case Level.fatal:
        return 'FATAL';
      default:
        return level.name.toUpperCase();
    }
  }

  String _stringify(dynamic message) {
    final m = message is Function ? message() : message;
    if (m is Map || m is Iterable) {
      return JsonEncoder.withIndent('  ').convert(m);
    }
    return m.toString();
  }

  _Frame? _callerFrame() {
    for (final line in StackTrace.current.toString().split('\n')) {
      final m = _frameRegex.firstMatch(line);
      if (m == null) continue;
      final loc = m.group(2)!; // package:.../file.dart:line:col
      // Skip the logging infrastructure frames.
      if (loc.startsWith('package:logger')) continue;
      if (loc.contains('util/app_log.dart')) continue;
      final lastColon = loc.lastIndexOf(':');
      final secondColon = loc.lastIndexOf(':', lastColon - 1);
      if (secondColon < 0) continue;
      var file = loc.substring(0, secondColon);
      if (file.contains('/lib/')) file = file.substring(file.indexOf('/lib/') + 5);
      final lineNo = loc.substring(secondColon + 1, lastColon);
      return _Frame(method: m.group(1)!, file: file, line: lineNo);
    }
    return null;
  }
}

class _Frame {
  const _Frame({required this.method, required this.file, required this.line});
  final String method;
  final String file;
  final String line;
}
