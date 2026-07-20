import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/map_config.dart';
import '../data/database.dart';

/// Map view for a single recorded ride.
///
/// Renders the recorded GPS track as a polyline over an OpenStreetMap-based
/// tile layer (OpenCycleMap when a Thunderforest key is configured, otherwise
/// plain OSM). The user can freely zoom and pan; the view initially frames the
/// whole route. Rides with no GPS fixes show a placeholder. If every fix shares
/// a single location (zero-area bounds), the map centers on that point at a
/// fixed zoom instead of fitting bounds, which would otherwise compute a
/// non-finite zoom and crash.
class RideMapTab extends StatelessWidget {
  const RideMapTab({super.key, required this.ride, required this.samples});

  final Ride ride;
  final List<Sample> samples;

  List<LatLng> get _points => samples.where((s) => s.lat != null && s.lon != null).map((s) => LatLng(s.lat!, s.lon!)).toList();

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final theme = Theme.of(context);

    if (points.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No GPS track recorded for this ride.', textAlign: TextAlign.center),
        ),
      );
    }

    final primary = theme.colorScheme.primary;

    // Distinct coordinates. If every fix shares one location the bounds have
    // zero area, which makes CameraFit compute a non-finite zoom and crash. In
    // that case we center on that single point at a fixed zoom instead.
    final unique = points.toSet();
    final MapOptions options;
    if (unique.length <= 1) {
      options = MapOptions(
        initialCenter: points.first,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      );
    } else {
      options = MapOptions(
        // Free zoom/pan interaction; initial view frames the whole route.
        // maxZoom caps the fit so a near-zero-area bounds can't produce an
        // infinite zoom.
        initialCameraFit: CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(48), maxZoom: 18),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      );
    }

    return FlutterMap(
      options: options,
      children: [
        TileLayer(urlTemplate: MapConfig.tileTemplate, userAgentPackageName: MapConfig.userAgentPackageName),
        PolylineLayer(
          polylines: [Polyline(points: points, strokeWidth: 4, color: primary, borderStrokeWidth: 1, borderColor: primary.withAlpha(80))],
        ),
        RichAttributionWidget(alignment: AttributionAlignment.bottomRight, attributions: [TextSourceAttribution(MapConfig.attribution)]),
      ],
    );
  }
}
