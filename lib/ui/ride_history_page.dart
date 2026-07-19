import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/recording_provider.dart';
import 'ride_details_page.dart';

/// All rides from the database, ordered by start time descending.
///
/// Re-fetches whenever [rideHistoryVersionProvider] is bumped (on every ride
/// start or stop).
final rideHistoryProvider = FutureProvider<List<Ride>>((ref) async {
  // Watch the version counter so this provider re-evaluates on start/stop.
  ref.watch(rideHistoryVersionProvider);

  debugPrint('[rideHistoryProvider] re-fetching rides from database');

  final db = ref.watch(databaseProvider);
  final rides = await db.select(db.rides).get();
  rides.sort((a, b) => b.startTime.compareTo(a.startTime));

  for (final r in rides) {
    debugPrint('[rideHistoryProvider]   ride #${r.id}: endTime=${r.endTime}');
  }

  return rides;
});

/// Page showing all recorded rides with summary info.
class RideHistoryPage extends ConsumerWidget {
  const RideHistoryPage({super.key, this.onNavigateBack});

  /// Called to navigate back to the ride screen.
  final VoidCallback? onNavigateBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(rideHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back to ride screen', onPressed: onNavigateBack),
      ),
      body: ridesAsync.when(
        data: (rides) {
          if (rides.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_bike, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text('No rides yet', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Record a ride to see it here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rides.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _RideCard(ride: rides[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load rides: $e')),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ride card
// ---------------------------------------------------------------------------

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final duration = ride.endTime?.difference(ride.startTime);
    final dateStr = _formatDate(ride.startTime);
    final timeStr = _formatTime(ride.startTime);
    final durationStr = duration != null ? _formatDuration(duration) : 'In progress…';
    final distanceStr = ride.distanceKm > 0 ? '${ride.distanceKm.toStringAsFixed(1)} km' : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // The ride currently "in progress" (endTime == null) is not opened.
          if (ride.endTime == null) return;
          Navigator.of(context).push(_scaleRoute(RideDetailsPage(ride: ride)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      ride.title?.isNotEmpty == true ? ride.title! : '$dateStr  $timeStr',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (ride.endTime == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('In progress', style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange)),
                    ),
                ],
              ),
              if (ride.title?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('$dateStr  $timeStr', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
              const SizedBox(height: 12),
              // Stats row
              Row(
                children: [
                  _Stat(icon: Icons.timer, label: 'Duration', value: durationStr),
                  if (distanceStr != null) ...[const SizedBox(width: 24), _Stat(icon: Icons.straighten, label: 'Distance', value: distanceStr)],
                  if (ride.avgHumanPowerW != null) ...[
                    const SizedBox(width: 24),
                    _Stat(icon: Icons.bolt, label: 'Avg Power', value: '${ride.avgHumanPowerW!.toStringAsFixed(0)} W'),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// A route that scales the page up from the center on push and scales it back
/// down on pop, giving a subtle zoom-in / zoom-out effect.
Route<T> _scaleRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final scale = Tween<double>(begin: 0.92, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)).animate(animation);
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(animation);
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}
