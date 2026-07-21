import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../ble/ble_scan_result.dart';
import '../providers/ble_provider.dart';
import '../util/app_log.dart';
import 'device_settings_dialog.dart';

/// Settings page showing BLE scan results with connect/disconnect controls.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  BleService? _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(bleServiceProvider);
    _service!.startScan();
  }

  @override
  void dispose() {
    _service?.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanResults = ref.watch(scanResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Devices'),
        actions: [
          IconButton(icon: const Icon(Icons.bug_report), tooltip: 'Share diagnostic log', onPressed: () => AppLog.share()),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan',
            onPressed: () {
              final service = ref.read(bleServiceProvider);
              service.stopScan();
              service.startScan();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: scanResults.when(
              data: (devices) {
                if (devices.isEmpty) {
                  return const Center(child: Text('No devices found.'));
                }
                // Sort: connected first, then by lastSeen (desc), then by name.
                final sorted = devices.toList()
                  ..sort((a, b) {
                    // Connected devices always on top.
                    if (a.isConnected != b.isConnected) {
                      return a.isConnected ? -1 : 1;
                    }
                    // Then by lastSeen (most recent first).
                    if (a.lastSeen != null && b.lastSeen != null) {
                      final cmp = b.lastSeen!.compareTo(a.lastSeen!);
                      if (cmp != 0) return cmp;
                    } else if (a.lastSeen != null) {
                      return -1;
                    } else if (b.lastSeen != null) {
                      return 1;
                    }
                    // Finally by name.
                    return a.name.compareTo(b.name);
                  });
                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _DeviceTile(device: sorted[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Scan error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device});
  final BleScanResult device;

  /// Module logger (auto-captures caller class + file:line).
  static final _log = AppLog.logFor('SettingsPage');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final service = ref.read(bleServiceProvider);
    final dashState = ref.watch(dashConnectionStateProvider).value;
    final hrmState = ref.watch(hrmConnectionStateProvider).value;

    final isConnected = device.isConnected;
    final isCyclingComputer = device.appearance == 0x0480;
    final isHrm = device.serviceUuids.any((u) => u.startsWith('180d')) || device.appearance == 0x0134;
    final dashConnected = dashState == BleConnectionState.connected;
    final hrmConnected = hrmState == BleConnectionState.connected;

    // Slot availability: at most one CC and one HRM.
    final canConnect = !isConnected && device.inRange && ((isCyclingComputer && !dashConnected) || (isHrm && !hrmConnected) || (!isCyclingComputer && !isHrm));

    // Icon based on appearance.
    IconData icon;
    Color iconColor;
    if (isCyclingComputer) {
      icon = Icons.pedal_bike;
      iconColor = Colors.green.shade600;
    } else if (isHrm) {
      icon = Icons.favorite;
      iconColor = Colors.red.shade600;
    } else {
      icon = Icons.devices_other;
      iconColor = Colors.grey;
    }

    final tile = ListTile(
      leading: Icon(icon, color: iconColor, size: 36),
      title: Text(device.name.isNotEmpty ? device.name : '(Unknown)'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(device.deviceId, style: theme.textTheme.bodySmall),
          if (device.rssi != null) Text('RSSI: ${device.rssi} dBm', style: theme.textTheme.bodySmall),
          if (!device.inRange && !isConnected) Text('Out of range — swipe to forget', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange)),
        ],
      ),
      trailing: isConnected
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCyclingComputer)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Device Settings',
                    onPressed: () {
                      showDialog(context: context, builder: (_) => const DeviceSettingsDialog());
                    },
                  ),
                OutlinedButton(
                  onPressed: () {
                    if (isCyclingComputer) {
                      service.disconnectDash();
                    } else if (isHrm) {
                      service.disconnectHrm();
                    } else {
                      _log.w('Disconnect button: Unknown device type: $device');
                      // We are connected to an unknown device type, so forget it.
                      service.forgetDevice(device.deviceId);
                    }
                    service.stopScan();
                    service.startScan();
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Disconnect'),
                ),
              ],
            )
          : canConnect
          ? FilledButton(
              onPressed: () {
                if (isCyclingComputer) {
                  service.connectToDash(device.deviceId, name: device.name);
                } else {
                  service.connectToHrm(device.deviceId, name: device.name);
                }
              },
              child: const Text('Connect'),
            )
          : null,
    );

    // Wrap out-of-range devices in a Dismissible so the user can swipe to forget.
    if (!device.inRange && !isConnected) {
      return Dismissible(
        key: ValueKey('forget-${device.deviceId}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) {
          // Forget this device: remove from cache and app storage.
          _log.d('Dismiss: Forgetting device: $device');
          service.forgetDevice(device.deviceId);
        },
        child: tile,
      );
    }

    return tile;
  }
}
