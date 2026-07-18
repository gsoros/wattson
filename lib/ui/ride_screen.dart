import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../providers/ble_provider.dart';
import 'settings_page.dart';

/// Basic live ride screen (M0/M3 placeholder).
class RideScreen extends ConsumerWidget {
  const RideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashState = ref.watch(dashConnectionStateProvider);
    final hrmState = ref.watch(hrmConnectionStateProvider);
    final telemetry = ref.watch(telemetryProvider);
    bool connected = dashState.value == BleConnectionState.connected || hrmState.value == BleConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wattson'),
        actions: [
          // Connection chip
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: Text(switch (dashState.value) {
                BleConnectionState.connected => 'Connected',
                BleConnectionState.connecting => 'Connecting…',
                BleConnectionState.scanning => 'Scanning…',
                BleConnectionState.disabled => 'Disabled',
                BleConnectionState.disconnected => 'Disconnected',
                null => '—',
              }),
            ),
          ),
          // Settings gear icon
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
      body: !connected
          ? Center(child: Text("No data, connect a device"))
          : telemetry.when(
              data: (t) {
                List<Widget> children = [];
                if (t.ordValid) {
                  children.addAll([
                    _Metric(label: 'Speed', value: '${t.speedKmh.toStringAsFixed(1)} km/h'),
                    _Metric(label: 'Human power', value: '${t.humanPowerW.toStringAsFixed(0)} W'),
                    _Metric(label: 'Motor power', value: '${t.motorPowerW.toStringAsFixed(0)} W'),
                    _Metric(label: 'Cadence', value: '${t.cadenceRpm} RPM'),
                    _Metric(label: 'PAS', value: '${t.pasLevel}'),
                    _Metric(label: 'Battery', value: '${t.soc}%  ${t.batteryVoltage.toStringAsFixed(1)} V'),
                    _Metric(label: 'Range', value: '${t.rangeKm.toStringAsFixed(1)} km'),
                  ]);
                }
                if (t.hrmValid) {
                  children.addAll([_Metric(label: 'Heart rate', value: t.heartRateBpm > 0 ? '${t.heartRateBpm} BPM' : '—')]);
                }
                return ListView(padding: const EdgeInsets.all(16), children: children);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Telemetry error: $e')),
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}
