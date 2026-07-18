import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../models/telemetry.dart';
import '../providers/ble_provider.dart';
import 'settings_page.dart';

/// Live ride screen (Phase 3).
///
/// Shows ORD Dash telemetry and HRM heart rate in a clean card layout:
///   - Speed as a hero metric (full-width).
///   - Secondary metrics in a 2-column grid (human power, motor power, cadence,
///     heart rate, PAS level, range).
///   - Battery summary row (SoC bar + voltage).
class RideScreen extends ConsumerWidget {
  const RideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashState = ref.watch(dashConnectionStateProvider);
    final hrmState = ref.watch(hrmConnectionStateProvider);
    final telemetry = ref.watch(telemetryProvider);
    final connected = dashState.value == BleConnectionState.connected || hrmState.value == BleConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wattson'),
        actions: [
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
          ? const Center(child: Text('No data — connect a device'))
          : telemetry.when(
              data: (t) => _RideContent(t: t),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Telemetry error: $e')),
            ),
    );
  }
}

/// The inner content so we can use non-const keys on the cards.
class _RideContent extends StatelessWidget {
  const _RideContent({required this.t});
  final Telemetry t;

  @override
  Widget build(BuildContext context) {
    final metrics = <Widget>[];

    // -- Hero speed --
    if (t.ordValid) {
      metrics.add(_SpeedTile(speedKmh: t.speedKmh));
    }

    // -- Secondary grid --
    final gridChildren = <Widget>[];
    if (t.ordValid) {
      gridChildren.addAll([
        _MetricTile(label: 'Human Power', value: t.humanPowerW.toStringAsFixed(0), unit: 'W'),
        _MetricTile(label: 'Motor Power', value: t.motorPowerW.toStringAsFixed(0), unit: 'W'),
        _MetricTile(label: 'Cadence', value: t.cadenceRpm.toString(), unit: 'RPM'),
        _MetricTile(label: 'PAS Level', value: t.pasLevel.toString(), unit: ''),
        _MetricTile(label: 'Range', value: t.rangeKm.toStringAsFixed(1), unit: 'km'),
      ]);
    }
    if (t.hrmValid) {
      gridChildren.add(_MetricTile(label: 'Heart Rate', value: t.heartRateBpm.toString(), unit: 'BPM'));
    }

    if (gridChildren.isNotEmpty) {
      metrics.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: gridChildren.map((child) => SizedBox(width: _gridChildWidth(context), child: child)).toList(),
          ),
        ),
      );
    }

    // -- Battery summary --
    if (t.ordValid) {
      metrics.add(_BatteryTile(soc: t.soc, voltage: t.batteryVoltage));
    }

    return ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 24), children: metrics);
  }

  double _gridChildWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // 2 columns with 8px gaps and 12px side padding
    return (width - 12 * 2 - 8) / 2;
  }
}

// ---------------------------------------------------------------------------
// Speed hero tile
// ---------------------------------------------------------------------------

class _SpeedTile extends StatelessWidget {
  const _SpeedTile({required this.speedKmh});
  final double speedKmh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(speedKmh.toStringAsFixed(1), style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('km/h', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Secondary metric tile (used in the 2-column grid)
// ---------------------------------------------------------------------------

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (unit.isNotEmpty) Text(unit, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Battery tile (SoC bar + voltage)
// ---------------------------------------------------------------------------

class _BatteryTile extends StatelessWidget {
  const _BatteryTile({required this.soc, required this.voltage});
  final int soc;
  final double voltage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = soc > 20 ? Colors.green : (soc > 10 ? Colors.orange : Colors.red);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Battery', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Text('${voltage.toStringAsFixed(1)} V', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: soc / 100.0,
                minHeight: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 4),
            Text('$soc%', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
