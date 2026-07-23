import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../ble/ble_scan_result.dart';
import '../providers/ble_provider.dart';
import '../util/app_log.dart';
import 'device_settings_dialog.dart';

/// Settings page.
/// For now the only setting is the device list: BLE scan results with connect/disconnect controls.
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
    _service!.stopScan();
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
        title: const Text('BLE Devices'), // We can rename this to "Settings" when we add more settings.
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
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _DeviceCard(key: ValueKey(sorted[index].deviceId), device: sorted[index]);
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

class _DeviceCard extends ConsumerStatefulWidget {
  const _DeviceCard({super.key, required this.device});
  final BleScanResult device;

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  static final _log = AppLog.logFor('SettingsPage');

  /// Local connecting flag — set immediately on press, reset when the
  /// connection state stream leaves the `connecting` state.
  bool _isConnecting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = ref.read(bleServiceProvider);
    final dashState = ref.watch(dashConnectionStateProvider).value;
    final hrmState = ref.watch(hrmConnectionStateProvider).value;

    final isConnected = widget.device.isConnected;
    final isCyclingComputer = widget.device.appearance == 0x0480;
    final isHrm = widget.device.serviceUuids.any((u) => u.startsWith('180d')) || widget.device.appearance == 0x0134;

    // Reset local state when the connection reaches a terminal state
    // (connected or disconnected). Don't react to intermediate states like
    // `scanning` which would immediately undo the local `_isConnecting`.
    ref.listen(dashConnectionStateProvider, (prev, next) {
      final state = next.value;
      if (isCyclingComputer && (state == BleConnectionState.connected || state == BleConnectionState.disconnected)) {
        setState(() => _isConnecting = false);
      }
    });
    ref.listen(hrmConnectionStateProvider, (prev, next) {
      final state = next.value;
      if (isHrm && (state == BleConnectionState.connected || state == BleConnectionState.disconnected)) {
        setState(() => _isConnecting = false);
      }
    });

    final dashConnected = dashState == BleConnectionState.connected;
    final hrmConnected = hrmState == BleConnectionState.connected;

    // Slot availability: at most one CC and one HRM.
    final canConnect =
        !isConnected &&
        !_isConnecting &&
        widget.device.inRange &&
        ((isCyclingComputer && !dashConnected) || (isHrm && !hrmConnected) || (!isCyclingComputer && !isHrm));

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

    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        spacing: 8.0,
        children: [
          Icon(icon, color: iconColor, size: 36),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16.0),
              Text(widget.device.name.isNotEmpty ? widget.device.name : '(Unknown)', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16.0),
              Text(widget.device.deviceId, style: theme.textTheme.bodySmall),
              if (widget.device.rssi != null) Text('RSSI: ${widget.device.rssi} dBm', style: theme.textTheme.bodySmall),
              Text(
                (!widget.device.inRange && !isConnected) ? 'Out of range — swipe to forget' : ' ',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
              ),
            ],
          ),
          const Expanded(child: SizedBox.shrink()),
          isConnected
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
                          _log.w('Disconnect button: Unknown device type: ${widget.device}');
                          // We are connected to an unknown device type, so forget it.
                          service.forgetDevice(widget.device.deviceId);
                        }
                        service.stopScan();
                        service.startScan();
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Disconnect'),
                    ),
                  ],
                )
              : _isConnecting
              ? FilledButton(
                  onPressed: null, // disabled
                  child: const Text('Connecting…'),
                )
              : canConnect
              ? FilledButton(
                  onPressed: () {
                    setState(() => _isConnecting = true);
                    if (isCyclingComputer) {
                      service.connectToDash(widget.device.deviceId, name: widget.device.name);
                    } else {
                      service.connectToHrm(widget.device.deviceId, name: widget.device.name);
                    }
                  },
                  child: const Text('Connect'),
                )
              : const SizedBox.shrink(),
        ],
      ),
    );

    // Wrap out-of-range devices in a Dismissible so the user can swipe to forget.
    if (!widget.device.inRange && !isConnected) {
      return Dismissible(
        key: ValueKey('forget-${widget.device.deviceId}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) {
          _log.d('Dismiss: Forgetting device: ${widget.device}');
          service.forgetDevice(widget.device.deviceId);
        },
        child: card,
      );
    }

    return card;
  }
}
