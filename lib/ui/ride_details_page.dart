import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../data/database.dart';
import '../providers/recording_provider.dart';
import '../util/ride_title_generator.dart';
import '../util/ride_metrics.dart';
import '../export/export_service.dart';
import 'ride_map.dart';

/// Formats a [DateTime] as e.g. "Jul 19, 2026 12:34" — used as the fallback ride
/// title when the user hasn't set a custom name.
String formatRideDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Detail view for a single recorded ride.
///
/// Shows all known ride metrics in collapsible sections, an editable title and
/// notes field, a delete action, and an embedded map with the optional overlay
/// graph.
class RideDetailsPage extends ConsumerStatefulWidget {
  const RideDetailsPage({super.key, required this.ride});

  final Ride ride;

  @override
  ConsumerState<RideDetailsPage> createState() => _RideDetailsPageState();
}

class _RideDetailsPageState extends ConsumerState<RideDetailsPage> {
  late Ride _ride;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _ftpController;
  final _titleFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _ftpFocus = FocusNode();
  bool _saving = false;
  bool _deleting = false;
  bool _exporting = false;
  AppDatabase? _db;
  Timer? _saveTimer;
  List<Sample> _samples = const [];
  List<PasLevelDistributionData> _pasDistribution = const [];

  // Section expansion state
  bool _rideSectionExpanded = true;
  bool _performanceSectionExpanded = true;
  bool _movementSectionExpanded = true;
  bool _assistanceSectionExpanded = true;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _titleController = TextEditingController(text: _ride.title ?? '');
    _notesController = TextEditingController(text: _ride.notes ?? '');
    _ftpController = TextEditingController(text: _ride.rideFtpW?.toStringAsFixed(0) ?? '');
    // Auto-save a few seconds after the user stops typing in either field.
    _titleController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
    _ftpController.addListener(_onFieldChanged);
    // Load the GPS track and PAS distribution.
    _loadRideData();
  }

  Future<void> _loadRideData() async {
    _db ??= ref.read(databaseProvider);
    final db = _db!;
    final samples = await (db.select(db.samples)..where((s) => s.rideId.equals(_ride.id))).get();
    final pasDist = await (db.select(db.pasLevelDistribution)..where((p) => p.rideId.equals(_ride.id))).get();
    if (mounted) {
      setState(() {
        _samples = samples;
        _pasDistribution = pasDist;
      });
    }
  }

  /// (Re)starts the debounce timer that triggers a save once typing pauses.
  void _onFieldChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _save);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleController.removeListener(_onFieldChanged);
    _notesController.removeListener(_onFieldChanged);
    _ftpController.removeListener(_onFieldChanged);
    _titleController.dispose();
    _notesController.dispose();
    _ftpController.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    _ftpFocus.dispose();
    super.dispose();
  }

  /// Persists title + notes + FTP. Empty title is stored as null so the UI
  /// falls back to the date label.
  Future<void> _save() async {
    if (_saving) return;
    _saveTimer?.cancel();
    final title = _titleController.text.trim();
    final notes = _notesController.text;
    final ftpText = _ftpController.text.trim();
    final ftp = double.tryParse(ftpText);
    // No-op if unchanged relative to the locally tracked ride.
    if (title == (_ride.title ?? '') && notes == (_ride.notes ?? '') && ftp == _ride.rideFtpW) return;

    setState(() => _saving = true);
    try {
      _db ??= ref.read(databaseProvider);
      final db = _db!;
      await db
          .update(db.rides)
          .replace(_ride.copyWith(title: Value(title.isEmpty ? null : title), notes: Value(notes.isEmpty ? null : notes), rideFtpW: Value(ftp)));
      // Reflect the saved values locally.
      _ride = _ride.copyWith(title: Value(title.isEmpty ? null : title), notes: Value(notes.isEmpty ? null : notes), rideFtpW: Value(ftp));
      // Keep the ride history list in sync with the edited title/notes.
      ref.read(rideHistoryVersionProvider.notifier).bump();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final db = ref.read(databaseProvider);
      final samples = await (db.select(db.samples)..where((s) => s.rideId.equals(_ride.id))).get();
      await shareRideGpx(ride: _ride, samples: samples);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ride?'),
        content: const Text('This permanently removes the ride and all of its recorded data. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      final service = ref.read(recordingServiceProvider);
      await service.deleteRide(_ride.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    final duration = ride.endTime?.difference(ride.startTime);
    final elapsedSec = duration?.inSeconds ?? 0;
    final movingSec = ride.timeInMotion.toInt();
    final stoppedSec = elapsedSec - movingSec;

    // Computed metrics
    final avgSpeed = elapsedSec > 0 ? (ride.distanceKm / (elapsedSec / 3600.0)) : null;
    final movingAvgSpeed = movingSec > 0 ? (ride.distanceKm / (movingSec / 3600.0)) : null;
    final np = ride.weightedAvgPowerW;
    final ftp = ride.rideFtpW;
    final if_ = computeIF(np, ftp);
    final tss = computeTSS(np, ftp, elapsedSec > 0 ? elapsedSec.toDouble() : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(ride.title?.isNotEmpty == true ? ride.title! : formatRideDate(ride.startTime)),
        actions: [
          IconButton(
            icon: _exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.share),
            tooltip: 'Export GPX',
            onPressed: _exporting ? null : _export,
          ),
          IconButton(
            icon: _deleting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete),
            tooltip: 'Delete ride',
            onPressed: _deleting ? null : _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -- Title row --
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'Name this ride', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                ),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'Suggest a title',
                  onPressed: _titleController.text.trim().isEmpty
                      ? () {
                          _titleController.text = generateRideTitle(_ride);
                          _save();
                        }
                      : null,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // -- Metrics card with collapsible sections --
          Card(
            margin: const EdgeInsets.all(0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Ride section ----
                  _SectionHeader(title: 'Ride', expanded: _rideSectionExpanded, onToggle: () => setState(() => _rideSectionExpanded = !_rideSectionExpanded)),
                  if (_rideSectionExpanded) ...[
                    _MetricRow(icon: Icons.calendar_today, label: 'Date', value: formatRideDate(ride.startTime)),
                    _MetricRow(icon: Icons.timer, label: 'Elapsed time', value: _formatDuration(duration ?? Duration.zero)),
                    _MetricRow(
                      icon: Icons.play_arrow,
                      label: 'Moving time',
                      value: _formatDuration(Duration(seconds: movingSec)),
                    ),
                    _MetricRow(
                      icon: Icons.pause,
                      label: 'Stopped time',
                      value: _formatDuration(Duration(seconds: stoppedSec < 0 ? 0 : stoppedSec)),
                    ),
                  ],

                  const Divider(),

                  // ---- Performance section ----
                  _SectionHeader(
                    title: 'Performance',
                    expanded: _performanceSectionExpanded,
                    onToggle: () => setState(() => _performanceSectionExpanded = !_performanceSectionExpanded),
                  ),
                  if (_performanceSectionExpanded) ...[
                    _MetricRow(
                      icon: Icons.bolt,
                      label: 'Average power (moving)',
                      value: ride.avgHumanPowerW != null ? '${ride.avgHumanPowerW!.toStringAsFixed(0)} W' : '—',
                    ),
                    _MetricRow(icon: Icons.show_chart, label: 'Weighted average power', value: np != null ? '${np.toStringAsFixed(0)} W' : '—'),
                    _MetricRow(icon: Icons.speed, label: 'Intensity', value: if_ != null ? if_.toStringAsFixed(2) : '—'),
                    _MetricRow(icon: Icons.fitness_center, label: 'Training Stress Score', value: tss != null ? tss.toStringAsFixed(1) : '—'),
                    _MetricRow(
                      icon: Icons.trending_up,
                      label: 'Maximum power',
                      value: ride.maxHumanPowerW != null ? '${ride.maxHumanPowerW!.toStringAsFixed(0)} W' : '—',
                    ),
                    // Editable FTP
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.settings, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Ride FTP', style: TextStyle(fontSize: 14))),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _ftpController,
                              focusNode: _ftpFocus,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                suffixText: 'W',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(),

                  // ---- Movement section ----
                  _SectionHeader(
                    title: 'Movement',
                    expanded: _movementSectionExpanded,
                    onToggle: () => setState(() => _movementSectionExpanded = !_movementSectionExpanded),
                  ),
                  if (_movementSectionExpanded) ...[
                    _MetricRow(icon: Icons.straighten, label: 'Distance', value: '${ride.distanceKm.toStringAsFixed(1)} km'),
                    _MetricRow(icon: Icons.terrain, label: 'Elevation gain', value: '${ride.elevationGainM.toStringAsFixed(0)} m'),
                    _MetricRow(icon: Icons.speed, label: 'Average speed', value: avgSpeed != null ? '${avgSpeed.toStringAsFixed(1)} km/h' : '—'),
                    _MetricRow(
                      icon: Icons.speed,
                      label: 'Moving average speed',
                      value: movingAvgSpeed != null ? '${movingAvgSpeed.toStringAsFixed(1)} km/h' : '—',
                    ),
                    _MetricRow(
                      icon: Icons.sync,
                      label: 'Average cadence',
                      value: ride.avgCadenceRpm != null ? '${ride.avgCadenceRpm!.toStringAsFixed(0)} rpm' : '—',
                    ),
                  ],

                  const Divider(),

                  // ---- Assistance section ----
                  _SectionHeader(
                    title: 'Assistance',
                    expanded: _assistanceSectionExpanded,
                    onToggle: () => setState(() => _assistanceSectionExpanded = !_assistanceSectionExpanded),
                  ),
                  if (_assistanceSectionExpanded) ...[
                    _MetricRow(
                      icon: Icons.electric_bolt,
                      label: 'Average motor power',
                      value: ride.avgMotorPowerW != null ? '${ride.avgMotorPowerW!.toStringAsFixed(0)} W' : '—',
                    ),
                    _MetricRow(
                      icon: Icons.battery_charging_full,
                      label: 'Motor energy',
                      value: ride.motorEnergyWh != null ? '${ride.motorEnergyWh!.toStringAsFixed(1)} Wh' : '—',
                    ),
                    _MetricRow(icon: Icons.balance, label: 'Assist ratio', value: ride.assistRatio != null ? ride.assistRatio!.toStringAsFixed(2) : '—'),
                    // PAS distribution
                    if (_pasDistribution.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'PAS level distribution',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      ..._pasDistribution.map((p) => _PasLevelRow(pasLevel: p.pasLevel, sampleCount: p.sampleCount)),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // -- Notes field --
          TextField(
            controller: _notesController,
            focusNode: _notesFocus,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Add notes about this ride',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 1,
            maxLines: null,
            textInputAction: TextInputAction.newline,
          ),

          const SizedBox(height: 16),

          // -- Embedded map --
          SizedBox(
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - kToolbarHeight - 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RideMap(ride: ride, samples: _samples),
            ),
          ),
        ],
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
// Collapsible section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.expanded, required this.onToggle});
  final String title;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more, size: 20, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric row
// ---------------------------------------------------------------------------

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAS level row (time spent at each level)
// ---------------------------------------------------------------------------

class _PasLevelRow extends StatelessWidget {
  const _PasLevelRow({required this.pasLevel, required this.sampleCount});
  final int pasLevel;
  final int sampleCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seconds = sampleCount; // ~1 Hz samples
    final label = pasLevel == -1
        ? 'Walk'
        : pasLevel == 0
        ? 'Off'
        : 'PAS $pasLevel';
    final timeStr = _formatDuration(Duration(seconds: seconds));

    return Padding(
      padding: const EdgeInsets.only(left: 30, top: 2, bottom: 2),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(timeStr, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
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
