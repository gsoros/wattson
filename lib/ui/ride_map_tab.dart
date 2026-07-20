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
/// whole route. Rides with no GPS fixes show a placeholder.
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

    return FlutterMap(
      options: MapOptions(
        // Free zoom/pan interaction; initial view frames the whole route.
        initialCameraFit: CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(48)),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
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
