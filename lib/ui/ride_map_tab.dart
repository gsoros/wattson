import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/map_config.dart';
import '../data/database.dart';
import 'map_settings_overlay.dart';
import 'ride_overlay_graph.dart';

/// Map view for a single recorded ride.
///
/// Renders the recorded GPS track as a polyline over a tile layer (selected in
/// Map Settings). A gear button (top-right) opens a semi-transparent Map
/// Settings overlay. When at least one graph metric slot is configured (not
/// "None"), a semi-transparent combined graph is drawn at the bottom; its
/// cursor drives a dot on the map, and pinch/range zooming the graph zooms the
/// map to the same distance window.
class RideMapTab extends StatefulWidget {
  const RideMapTab({super.key, required this.ride, required this.samples});

  final Ride ride;
  final List<Sample> samples;

  @override
  State<RideMapTab> createState() => _RideMapTabState();
}

class _RideMapTabState extends State<RideMapTab> {
  final MapController _mapController = MapController();

  /// GPS-valid track points, aligned to [widget.samples].
  List<LatLng> _points = const [];

  /// GPS-valid samples, aligned to [_points].
  List<Sample> _gpsSamples = const [];

  /// Cumulative distance (km) per GPS-valid sample, aligned to [_points].
  List<double> _distances = const [];

  bool _showSettings = false;

  /// Distance (km) of the cursor, or null when not placed.
  double? _cursorDist;

  @override
  void initState() {
    super.initState();
    _computeTrack();
  }

  @override
  void didUpdateWidget(covariant RideMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.samples != widget.samples) _computeTrack();
  }

  void _computeTrack() {
    _gpsSamples = widget.samples.where((s) => s.lat != null && s.lon != null).toList();
    _points = _gpsSamples.map((s) => LatLng(s.lat!, s.lon!)).toList();
    _distances = [];
    double distanceKm = 0;
    DateTime? prevTs;
    for (final s in _gpsSamples) {
      if (prevTs != null) {
        final dtH = s.ts.difference(prevTs).inMilliseconds / 3600000.0;
        if (dtH > 0) distanceKm += s.speedKmh * dtH;
      }
      prevTs = s.ts;
      _distances.add(distanceKm);
    }
  }

  /// Index of the GPS sample whose distance is closest to [km].
  int _nearestIndex(double km) {
    if (_distances.isEmpty) return 0;
    var lo = 0;
    var hi = _distances.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_distances[mid] < km) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0 && (lo == _distances.length || (_distances[lo] - km) > (km - _distances[lo - 1]))) {
      lo -= 1;
    }
    return lo;
  }

  /// Fits the map camera to the GPS samples within [startKm, endKm].
  void _fitToRange(double startKm, double endKm) {
    final inRange = <LatLng>[];
    for (var i = 0; i < _distances.length; i++) {
      if (_distances[i] >= startKm && _distances[i] <= endKm) inRange.add(_points[i]);
    }
    if (inRange.isEmpty) return;
    _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(inRange), padding: const EdgeInsets.all(48), maxZoom: 18));
  }

  /// Fits the map camera to the whole route.
  void _resetView() {
    if (_points.isEmpty) return;
    _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(_points), padding: const EdgeInsets.all(48), maxZoom: 18));
  }

  LatLngBounds _initialBounds() => LatLngBounds.fromPoints(_points);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = Color(MapConfig.strokeColor ?? MapConfig.defaultStrokeColor);

    if (_points.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No GPS track recorded for this ride.', textAlign: TextAlign.center),
        ),
      );
    }

    // Cursor dot marker (only when a cursor distance is set and within range).
    final markers = <Marker>[];
    if (_cursorDist != null) {
      final idx = _nearestIndex(_cursorDist!);
      markers.add(
        Marker(
          point: _points[idx],
          width: 16,
          height: 16,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.error,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    }

    final mapOptions = _points.toSet().length <= 1
        ? MapOptions(
            initialCenter: _points.first,
            initialZoom: 16,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(bounds: _initialBounds(), padding: const EdgeInsets.all(48), maxZoom: 18),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
          );

    final map = FlutterMap(
      mapController: _mapController,
      options: mapOptions,
      children: [
        TileLayer(urlTemplate: MapConfig.tileTemplate, userAgentPackageName: MapConfig.userAgentPackageName),
        PolylineLayer(
          polylines: [Polyline(points: _points, strokeWidth: MapConfig.strokeWidth, color: primary, borderStrokeWidth: 1, borderColor: primary.withAlpha(80))],
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );

    return Stack(
      children: [
        map,
        // Gear button (top-right) — toggles the Map Settings overlay.
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: theme.colorScheme.surface.withAlpha(204),
            shape: const CircleBorder(),
            elevation: 2,
            child: IconButton(icon: const Icon(Icons.settings), tooltip: 'Map settings', onPressed: () => setState(() => _showSettings = !_showSettings)),
          ),
        ),
        // Bottom combined graph (two selectable metric slots). Only shown when
        // at least one slot is configured (not "None").
        if (MapConfig.graphMetric1 != GraphMetric.none || MapConfig.graphMetric2 != GraphMetric.none)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RideOverlayGraph(
              samples: _gpsSamples,
              metric1: MapConfig.graphMetric1,
              metric2: MapConfig.graphMetric2,
              color1: theme.colorScheme.primary,
              color2: theme.colorScheme.tertiary,
              onCursorChanged: (km) => setState(() => _cursorDist = km),
              onViewRangeChanged: _fitToRange,
              onResetView: _resetView,
            ),
          ),
        // Map Settings overlay — drawn last so it sits above the graph.
        if (_showSettings) MapSettingsOverlay(onChanged: () => setState(() {}), onClose: () => setState(() => _showSettings = false)),
        // Tile attribution (top-left, above the graph so it's never obscured).
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: theme.colorScheme.surface.withAlpha(204), borderRadius: BorderRadius.circular(6)),
            child: Text(MapConfig.attribution, style: theme.textTheme.labelSmall),
          ),
        ),
      ],
    );
  }
}
