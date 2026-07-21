import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../util/app_log.dart';
import 'nus_protocol.dart';

/// Serialized command queue for NUS communication with the ORD Dash.
///
/// Owns the NUS RX write and TX notify reassembly. Processes commands one at
/// a time with a configurable inter-command delay. Retries failed commands
/// (timeout or error reply) up to [maxRetries] times.
///
/// ## Deduplication
///
/// If [enqueue] is called with a command string that already exists in the
/// queue (including the currently-active command), the existing entry is
/// **overwritten** — its completer is replaced and a warning is logged. This
/// prevents stale commands from accumulating when the UI sends updates faster
/// than the queue can process them.
class NusCommandQueue {
  NusCommandQueue({this.interCommandDelay = const Duration(milliseconds: 100)});

  /// Module logger.
  static final _log = AppLog.logFor('NusCmdQueue');

  /// Delay between successive command writes.
  final Duration interCommandDelay;

  // -- NUS characteristics (set by owner) --

  BluetoothCharacteristic? _nusRxChar;

  /// Set the NUS RX characteristic for writing commands.
  void setNusRxChar(BluetoothCharacteristic? char) {
    _nusRxChar = char;
  }

  // -- Queue state --

  final List<_QueueEntry> _queue = [];
  bool _processing = false;

  // -- Active command state --

  /// Completer for the currently-active command (being written or awaiting reply).
  Completer<NusReply?>? _activeCompleter;

  /// The command string of the currently-active command (for dedup).
  String? _activeCommand;

  /// Remaining retries for the active command.
  int _activeRetries = 0;

  /// Timer for the inter-command delay.
  Timer? _delayTimer;

  // -- NUS TX reassembly state --

  int? _expectedLen;
  final List<int> _buffer = [];

  /// Enqueue a command to be sent over NUS.
  ///
  /// Returns a [Future] that completes with the parsed [NusReply] on success,
  /// or `null` if the queue is not connected (no RX characteristic).
  ///
  /// If [command] already exists in the queue (including the currently-active
  /// command), the existing entry is overwritten and a warning is logged.
  Future<NusReply?> enqueue(String command, {int maxRetries = 3, Duration timeout = const Duration(seconds: 5)}) {
    if (_nusRxChar == null) {
      _log.w('enqueue: no RX char, dropping "$command"');
      return Future.value(null);
    }

    // Check for duplicate in the pending queue.
    final existingIdx = _queue.indexWhere((e) => e.command == command);
    if (existingIdx >= 0) {
      _log.w('enqueue: overwriting duplicate "$command" in queue');
      final existing = _queue[existingIdx];
      final completer = Completer<NusReply?>();
      _queue[existingIdx] = _QueueEntry(command: command, completer: completer, maxRetries: maxRetries, timeout: timeout);
      existing.completer.completeError('overwritten');
      return completer.future;
    }

    // Check for duplicate in the active command.
    if (command == _activeCommand && _activeCompleter != null) {
      _log.w('enqueue: overwriting active command "$command"');
      final completer = Completer<NusReply?>();
      final oldCompleter = _activeCompleter!;
      _activeCompleter = completer;
      oldCompleter.completeError('overwritten');
      return completer.future;
    }

    final completer = Completer<NusReply?>();
    _queue.add(_QueueEntry(command: command, completer: completer, maxRetries: maxRetries, timeout: timeout));

    _processNext();
    return completer.future;
  }

  /// Called by the owner when NUS TX notification data arrives.
  ///
  /// Handles reassembly of fragmented replies (2-byte big-endian length prefix
  /// on the first frame). When a complete reply is assembled, it is parsed and
  /// the active command's completer is resolved.
  void onNusTxData(List<int> data) {
    if (_activeCompleter == null) return;

    if (_expectedLen == null) {
      // First frame: 2-byte big-endian total length prefix.
      if (data.length < 2) return;
      _expectedLen = (data[0] << 8) | data[1];
      _buffer.addAll(data.sublist(2));
    } else {
      _buffer.addAll(data);
    }

    if (_buffer.length >= _expectedLen!) {
      final raw = utf8.decode(_buffer.take(_expectedLen!).toList(), allowMalformed: true);
      _buffer.clear();
      _expectedLen = null;

      final reply = NusReply.parse(raw);
      if (reply != null) {
        _log.d('onNusTxData: ${reply.command} — ${reply.code} — ${reply.data}');
        if (reply.isSuccess) {
          _completeActive(reply);
        } else {
          _handleErrorReply(reply);
        }
      } else {
        _log.w('onNusTxData: failed to parse reply: "$raw"');
        _retryOrFail();
      }
    }
  }

  /// Cancel all pending and active commands.
  ///
  /// Called on Dash disconnect. All pending futures complete with `null`.
  void cancelAll() {
    _delayTimer?.cancel();
    _delayTimer = null;

    for (final entry in _queue) {
      entry.completer.complete(null);
    }
    _queue.clear();

    if (_activeCompleter != null) {
      _activeCompleter!.complete(null);
      _activeCompleter = null;
    }
    _activeCommand = null;
    _processing = false;
    _buffer.clear();
    _expectedLen = null;
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _processNext() {
    if (_processing || _queue.isEmpty) return;
    _processing = true;

    final entry = _queue.removeAt(0);
    _activeCommand = entry.command;
    _activeRetries = entry.maxRetries;
    _activeCompleter = entry.completer;

    _sendWithTimeout(entry);
  }

  Future<void> _sendWithTimeout(_QueueEntry entry) async {
    final rx = _nusRxChar;
    if (rx == null) {
      _completeActive(null);
      return;
    }

    _log.d('send: "${entry.command}"');

    try {
      await rx.write(utf8.encode(entry.command), withoutResponse: false);
    } catch (e) {
      _log.e('write failed: $e — device may have rebooted', error: e);
      // Write failure means the connection is gone (e.g. device rebooted).
      // Retrying would just get another GATT_ERROR. Fail immediately.
      _completeActive(NusReply(command: entry.command, code: NusReplyCode.executionError, data: 'write failed'));
      return;
    }

    // Wait for the reply or timeout.
    try {
      await _activeCompleter!.future.timeout(entry.timeout);
    } on TimeoutException {
      _log.w('timeout for "${entry.command}"');
      _retryOrFail();
    }
  }

  void _handleErrorReply(NusReply reply) {
    _log.w('error reply for "$_activeCommand": ${reply.code} — ${reply.data}');
    // Non-success replies count as failures — retry unless it's an
    // UnknownCommand (which won't change on retry).
    if (reply.code == NusReplyCode.unknownCommand) {
      _completeActive(reply);
    } else {
      _retryOrFail();
    }
  }

  void _retryOrFail() {
    // If the RX char is gone (device disconnected), fail immediately.
    if (_nusRxChar == null) {
      _log.d('device disconnected, giving up on "$_activeCommand"');
      _completeActive(NusReply(command: _activeCommand ?? '', code: NusReplyCode.executionError, data: 'disconnected'));
      return;
    }

    if (_activeRetries > 0) {
      _activeRetries--;
      _log.d('retrying "$_activeCommand" (${_activeRetries + 1} retries left)');
      // Re-create the completer for the retry.
      final command = _activeCommand!;
      final maxRetries = _activeRetries;
      final completer = Completer<NusReply?>();
      final oldCompleter = _activeCompleter!;
      _activeCompleter = completer;
      oldCompleter.complete(null); // Fail the original attempt.

      _sendWithTimeout(_QueueEntry(command: command, completer: completer, maxRetries: maxRetries, timeout: const Duration(seconds: 5)));
    } else {
      _log.d('giving up on "$_activeCommand"');
      _completeActive(NusReply(command: _activeCommand ?? '', code: NusReplyCode.executionError, data: 'timeout'));
    }
  }

  void _completeActive(NusReply? reply) {
    _activeCompleter?.complete(reply);
    _activeCompleter = null;
    _activeCommand = null;
    _buffer.clear();
    _expectedLen = null;
    _processing = false;

    // Schedule next command after the inter-command delay.
    if (_queue.isNotEmpty) {
      _delayTimer?.cancel();
      _delayTimer = Timer(interCommandDelay, _processNext);
    }
  }
}

/// Internal queue entry.
class _QueueEntry {
  _QueueEntry({required this.command, required this.completer, this.maxRetries = 3, this.timeout = const Duration(seconds: 5)});

  final String command;
  final Completer<NusReply?> completer;
  final int maxRetries;
  final Duration timeout;
}
