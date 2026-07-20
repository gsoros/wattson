import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../models/recording_state.dart';
import '../models/telemetry.dart';
import '../providers/ble_provider.dart';
import '../providers/recording_provider.dart';
import 'ride_history_page.dart';
import 'settings_page.dart';

/// Live ride screen (Phase 4).
///
/// Shows ORD Dash telemetry and HRM heart rate in a clean card layout, with
/// recording controls at the bottom.
class MainPage extends ConsumerWidget {
  const MainPage({super.key});

  /// Pushes the Ride History page. Shared by the history button and the
  /// swipe-right gesture so navigation stays in one place.
  void _openHistory(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RideHistoryPage()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashState = ref.watch(dashConnectionStateProvider);
    final hrmState = ref.watch(hrmConnectionStateProvider);
    final telemetry = ref.watch(telemetryProvider);
    final recordingAsync = ref.watch(recordingStateProvider);
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
          IconButton(icon: const Icon(Icons.history), tooltip: 'Ride History', onPressed: () => _openHistory(context)),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
      body: GestureDetector(
        // Swipe left anywhere on the main page to open Ride History.
        // Negative primaryVelocity means the drag ended moving to the left.
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < 200) {
            _openHistory(context);
          }
        },
        child: Stack(
          children: [
            // Main content
            !connected
                ? const Center(child: Text('No data — connect a device'))
                : telemetry.when(
                    data: (t) => _RideContent(t: t),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Telemetry error: $e')),
                  ),
            // Recording controls always visible at the bottom.
            Align(
              alignment: Alignment.bottomCenter,
              child: recordingAsync.when(
                data: (rs) => _RecordingControlBar(rs: rs, canRecord: connected),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recording control bar
// ---------------------------------------------------------------------------

class _RecordingControlBar extends ConsumerWidget {
  const _RecordingControlBar({required this.rs, required this.canRecord});
  final RecordingState rs;
  final bool canRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(recordingServiceProvider);
    final theme = Theme.of(context);

    Widget button;
    String? label;

    switch (rs.status) {
      case RecordingStatus.idle:
        button = FloatingActionButton.large(
          heroTag: 'record',
          onPressed: canRecord ? () => service.start() : null,
          backgroundColor: canRecord ? Colors.red : theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.fiber_manual_record, color: canRecord ? Colors.white : theme.colorScheme.onSurfaceVariant),
        );
        label = canRecord ? 'Record' : 'Connect a device to record';
      case RecordingStatus.recording:
        button = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HoldToConfirmButton(
              icon: Icons.pause,
              backgroundColor: Colors.orange,
              iconColor: Colors.white,
              tooltip: 'Hold to pause',
              onConfirmed: () => service.pause(),
            ),
            const SizedBox(width: 48),
            _HoldToConfirmButton(
              icon: Icons.stop,
              backgroundColor: Colors.red,
              iconColor: Colors.white,
              tooltip: 'Hold to stop',
              onConfirmed: () => service.stop(),
            ),
          ],
        );
      // This info is already shown in _RideConttent _TripStats
      //label = '${_formatDuration(rs.elapsed)}  ·  ${rs.distanceKm.toStringAsFixed(1)} km';
      case RecordingStatus.paused:
        button = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HoldToConfirmButton(
              icon: Icons.fiber_manual_record,
              backgroundColor: Colors.red,
              iconColor: Colors.white,
              tooltip: 'Hold to resume',
              onConfirmed: () => service.resume(),
            ),
            const SizedBox(width: 48),
            _HoldToConfirmButton(
              icon: Icons.stop,
              backgroundColor: Colors.grey,
              iconColor: Colors.white,
              tooltip: 'Hold to stop',
              onConfirmed: () => service.stop(),
            ),
          ],
        );
        label = 'Paused  ·  ${_formatDuration(rs.elapsed)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label ?? '', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            button,
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

// ---------------------------------------------------------------------------
// Hold-to-confirm button (progress ring)
// ---------------------------------------------------------------------------
//
// Used for destructive / easy-to-miss actions (pause, stop, resume) so they
// can't be triggered by an accidental tap. The user must press and hold; a
// circular indicator fills over ~600 ms and the action only fires once the
// ring completes. Releasing early cancels.

class _HoldToConfirmButton extends StatefulWidget {
  const _HoldToConfirmButton({required this.icon, required this.backgroundColor, required this.onConfirmed, this.iconColor = Colors.white, this.tooltip});

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onConfirmed;
  final String? tooltip;

  @override
  State<_HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<_HoldToConfirmButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// True once a full hold completes, so the trailing tap (which fires after
  /// the finger lifts) doesn't also pop the "press and hold" hint.
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _confirmed = true;
      widget.onConfirmed();
    }
  }

  void _start() {
    _confirmed = false;
    _controller.forward();
  }

  void _cancel() {
    switch (_controller.status) {
      case AnimationStatus.forward:
        _controller.reverse();
      case AnimationStatus.completed:
        _controller.value = 0; // reset after the user releases
      case AnimationStatus.reverse:
      case AnimationStatus.dismissed:
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: () => _cancel(),
        onTap: () {
          // A quick tap (no hold) shouldn't fire the action — instead hint
          // the user that a press-and-hold is required. Skip the hint when a
          // full hold just completed (the action already fired).
          if (_confirmed) return;
          final hint = widget.tooltip?.replaceFirst('Hold to', 'Press and hold to');
          if (hint != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint), duration: const Duration(seconds: 1)));
          }
        },
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            // Allow the ring to overflow the button so a finger resting on it
            // doesn't obscure the animation.
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Large, obvious ring drawn only while the user is holding
              // (value > 0). When idle it's invisible, so the button looks
              // like a normal FAB until pressed.
              if (_controller.value > 0)
                SizedBox(
                  width: 512,
                  height: 512,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CircularProgressIndicator(
                      value: _controller.value,
                      strokeWidth: 64,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
                      valueColor: AlwaysStoppedAnimation(widget.iconColor),
                    ),
                  ),
                ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.backgroundColor),
                child: Icon(widget.icon, color: widget.iconColor, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The inner content so we can use non-const keys on the cards.
class _RideContent extends ConsumerWidget {
  const _RideContent({required this.t});
  final Telemetry t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = <Widget>[];
    final rs = ref.watch(recordingStateProvider).asData?.value;

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
        _MetricTile(label: 'Range', value: t.rangeKm.toStringAsFixed(0), unit: 'km'),
      ]);
    }
    if (t.hrmValid) {
      gridChildren.add(_MetricTile(label: 'Heart Rate', value: t.heartRateBpm.toString(), unit: 'BPM'));
    }

    if (gridChildren.isNotEmpty) {
      metrics.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 0.0),
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
      metrics.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(0.0, 4.0, 0.0, 0.0),
          child: _BatteryTile(soc: t.soc, voltage: t.batteryVoltage),
        ),
      );
    }

    // -- Trip stats (shown while recording) --
    if (rs != null && rs.isActive) {
      metrics.add(_TripStatsTile(elapsed: rs.elapsed, distanceKm: rs.distanceKm, elevationGainM: rs.elevationGainM));
    }

    return metrics.isEmpty || (!t.ordValid && !t.hrmValid)
        ? const Text('Waiting for data  ...')
        : ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 120), // bottom padding for control bar
            children: metrics,
          );
  }

  double _gridChildWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // 2 columns with 8px gaps and 12px side padding
    return (width - 12 * 2 - 8) / 2;
  }
}

// ---------------------------------------------------------------------------
// Trip stats tile (shown while recording)
// ---------------------------------------------------------------------------

class _TripStatsTile extends StatelessWidget {
  const _TripStatsTile({required this.elapsed, required this.distanceKm, required this.elevationGainM});
  final Duration elapsed;
  final double distanceKm;
  final double elevationGainM;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(theme: theme, label: 'Time', value: _fmt(elapsed)),
            _Stat(theme: theme, label: 'Distance', value: '${distanceKm.toStringAsFixed(1)} km'),
            _Stat(theme: theme, label: 'Climb', value: '${elevationGainM.toStringAsFixed(0)} m'),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.theme, required this.label, required this.value});
  final ThemeData theme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text(speedKmh.toStringAsFixed(1), style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold)),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 80, maxHeight: 80),
      child: Card(
        margin: const EdgeInsets.all(0.0),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter, // const FractionalOffset(0.5, -1.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: Text(
                    value,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 0.85, // Collapses the bounding box height to the text size
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              if (unit.isNotEmpty)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(unit, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
            ],
          ),
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
