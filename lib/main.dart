import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/map_config.dart';
import 'providers/ble_provider.dart';
import 'ui/main_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the persisted Thunderforest API key for the Map tab before the UI
  // renders, so the first map view uses the correct tile source.
  MapConfig.load();

  // Initialize foreground service options (actual start/stop is driven by
  // RecordingService). Must happen before runApp.
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'wattson_recording',
      channelName: 'Ride Recording',
      channelDescription: 'Notification shown while a ride is being recorded.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
    ),
  );

  runApp(const ProviderScope(child: WattsonApp()));
}

class WattsonApp extends ConsumerWidget {
  const WattsonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger auto-connect on app start.
    ref.read(autoConnectProvider);

    return MaterialApp(
      title: 'Wattson',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
      ),
      themeMode: ThemeMode.system,
      home: const MainPage(),
    );
  }
}
