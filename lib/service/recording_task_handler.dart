import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Top-level callback invoked in the **background isolate** when the foreground
/// service starts. Registers the task handler so that notification + wake-lock
/// life-cycle runs in the isolate created by ForegroundService.
///
/// Must be annotated with @pragma('vm:entry-point') so the Dart VM keeps it
/// available for the callback handle lookup.
@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

/// Minimal task handler for the foreground service.
///
/// The actual BLE/recording work stays on the **main isolate** (per plan
/// decision). This handler only exists so that the notification + wake-lock
/// is held; `onRepeatEvent` and `onReceiveData` are unused.
class RecordingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // No-op — main isolate handles all logic.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op — main isolate handles all logic.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // No-op.
  }
}
