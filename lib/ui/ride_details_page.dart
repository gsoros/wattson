import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../data/database.dart';
import '../providers/recording_provider.dart';
import '../util/ride_title_generator.dart';
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
/// Shows all known ride metrics, an editable title and notes field, a
/// delete action, and an embedded map with the optional overlay graph.
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
  final _titleFocus = FocusNode();
  final _notesFocus = FocusNode();
  bool _saving = false;
  bool _deleting = false;
  bool _exporting = false;
  AppDatabase? _db;
  Timer? _saveTimer;
  List<Sample> _samples = const [];

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _titleController = TextEditingController(text: _ride.title ?? '');
    _notesController = TextEditingController(text: _ride.notes ?? '');
    // Auto-save a few seconds after the user stops typing in either field.
    _titleController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
    // Load the GPS track for the Map tab.
    _loadSamples();
  }

  Future<void> _loadSamples() async {
    _db ??= ref.read(databaseProvider);
    final db = _db!;
    final samples = await (db.select(db.samples)..where((s) => s.rideId.equals(_ride.id))).get();
    if (mounted) setState(() => _samples = samples);
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
    _titleController.dispose();
    _notesController.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  /// Persists title + notes. Empty title is stored as null so the UI falls
  /// back to the date label.
  Future<void> _save() async {
    if (_saving) return;
    _saveTimer?.cancel();
    final title = _titleController.text.trim();
    final notes = _notesController.text;
    // No-op if unchanged relative to the locally tracked ride. Comparing against
    // the original widget.ride would be wrong: that object never updates after
    // the first save, so re-entering a previously saved value would be skipped.
    if (title == (_ride.title ?? '') && notes == (_ride.notes ?? '')) return;

    setState(() => _saving = true);
    try {
      _db ??= ref.read(databaseProvider);
      final db = _db!;
      await db.update(db.rides).replace(_ride.copyWith(title: Value(title.isEmpty ? null : title), notes: Value(notes.isEmpty ? null : notes)));
      // Reflect the saved values locally so subsequent blur checks are correct.
      _ride = _ride.copyWith(title: Value(title.isEmpty ? null : title), notes: Value(notes.isEmpty ? null : notes));
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
                  // Only suggest when the field is empty, so we never clobber input.
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
          Card(
            margin: const EdgeInsets.all(0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetricRow(icon: Icons.calendar_today, label: 'Date', value: formatRideDate(ride.startTime)),
                  _MetricRow(icon: Icons.timer, label: 'Duration', value: duration != null ? _formatDuration(duration) : '—'),
                  _MetricRow(icon: Icons.straighten, label: 'Distance', value: '${ride.distanceKm.toStringAsFixed(1)} km'),
                  _MetricRow(icon: Icons.terrain, label: 'Elevation gain', value: '${ride.elevationGainM.toStringAsFixed(0)} m'),
                  _MetricRow(
                    icon: Icons.bolt,
                    label: 'Avg human power',
                    value: ride.avgHumanPowerW != null ? '${ride.avgHumanPowerW!.toStringAsFixed(0)} W' : '—',
                  ),
                  _MetricRow(
                    icon: Icons.bolt,
                    label: 'Max human power',
                    value: ride.maxHumanPowerW != null ? '${ride.maxHumanPowerW!.toStringAsFixed(0)} W' : '—',
                  ),
                  _MetricRow(
                    icon: Icons.electric_bolt,
                    label: 'Avg motor power',
                    value: ride.avgMotorPowerW != null ? '${ride.avgMotorPowerW!.toStringAsFixed(0)} W' : '—',
                  ),
                  _MetricRow(icon: Icons.sync, label: 'Avg cadence', value: ride.avgCadenceRpm != null ? '${ride.avgCadenceRpm!.toStringAsFixed(0)} rpm' : '—'),
                  _MetricRow(icon: Icons.favorite, label: 'Avg heart rate', value: ride.avgHrBpm != null ? '${ride.avgHrBpm!.toStringAsFixed(0)} bpm' : '—'),
                  _MetricRow(icon: Icons.balance, label: 'Assist ratio', value: ride.assistRatio != null ? ride.assistRatio!.toStringAsFixed(2) : '—'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            focusNode: _notesFocus,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Add notes about this ride',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            // Single line by default; grows vertically as content is added.
            minLines: 1,
            maxLines: null,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 16),
          // Embedded map with the optional overlay graph. Sized to fill the
          // visible scroll area (screen minus app bar and status bar) minus a
          // small gap, so it occupies most of the view when scrolled to bottom.
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
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

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
