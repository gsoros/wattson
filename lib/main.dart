import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/ble_provider.dart';
import 'ui/ride_history_page.dart';
import 'ui/main_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: const _MainShell(),
    );
  }
}

/// Root shell with a PageView for swipe navigation between the ride screen
/// and the ride history page.
class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  final _pageController = PageController(initialPage: 0);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showMainPage() {
    _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _showHistory() {
    _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      children: [
        MainPage(onShowHistory: _showHistory),
        RideHistoryPage(onNavigateBack: _showMainPage),
      ],
    );
  }
}
