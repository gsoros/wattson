import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/database.dart';

/// A semi-transparent combined Elevation / Human-Power overlay graph drawn at
/// the bottom of the ride map.
///
/// The horizontal axis is cumulative distance (km), integrated from speed × Δt
/// (the same formula used by the GPX exporter). The vertical axis shows
/// elevation (m, left) and human power (W, right) as two overlaid line series.
///
/// Interaction:
///  * Tap / drag  → moves the cursor to the nearest sample; the parent moves a
///    dot on the map to the matching GPS fix.
///  * Pinch        → zooms the visible distance window around the focal point;
///    the parent zooms the map to the same range.
///  * Long-press   → defines a range: the first long-press sets the start, the
///    second sets the end; the view zooms to that range.
///  * Double-tap   → resets the view to the full ride range.
class RideOverlayGraph extends StatefulWidget {
  const RideOverlayGraph({
    super.key,
    required this.samples,
    required this.showElevation,
    required this.showPower,
    required this.onCursorChanged,
    required this.onViewRangeChanged,
    required this.onResetView,
  });

  /// GPS-valid ride samples (lat/lon non-null), in time order.
  final List<Sample> samples;

  /// Whether the Elevation series is drawn.
  final bool showElevation;

  /// Whether the Power series is drawn.
  final bool showPower;

  /// Called with the distance (km) of the sample under the cursor.
  final ValueChanged<double> onCursorChanged;

  /// Called when the visible distance window changes (pinch / range select).
  final void Function(double startKm, double endKm) onViewRangeChanged;

  /// Called on double-tap to reset the view to the full ride.
  final VoidCallback onResetView;

  @override
  State<RideOverlayGraph> createState() => _RideOverlayGraphState();
}

class _RideOverlayGraphState extends State<RideOverlayGraph> {
  // Precomputed per-sample series, aligned to [widget.samples].
  // Mutable (not `late final`) because [_computeSeries] may run again when the
  // widget is updated with new samples.
  List<double> _distances = const []; // cumulative km
  List<double> _elevations = const []; // m (may contain nulls -> NaN)
  List<double> _powers = const []; // W
  double _totalDistance = 0;
  double _elevMin = 0;
  double _elevMax = 1;
  double _powerMin = 0;
  double _powerMax = 1;

  // Visible distance window (km).
  double _viewStart = 0;
  double _viewEnd = 0;

  // Cursor distance (km), or null when not yet placed.
  double? _cursorDist;

  // Range-select state (set by long-press).
  double? _rangeStart;

  @override
  void initState() {
    super.initState();
    _computeSeries();
  }

  @override
  void didUpdateWidget(covariant RideOverlayGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.samples != widget.samples || oldWidget.showElevation != widget.showElevation || oldWidget.showPower != widget.showPower) {
      _computeSeries();
    }
  }

  void _computeSeries() {
    final samples = widget.samples;
    _distances = [];
    _elevations = [];
    _powers = [];
    double distanceKm = 0;
    DateTime? prevTs;
    double? elevMin;
    double? elevMax;
    double? powerMin;
    double? powerMax;
    for (final s in samples) {
      if (prevTs != null) {
        final dtH = s.ts.difference(prevTs).inMilliseconds / 3600000.0;
        if (dtH > 0) distanceKm += s.speedKmh * dtH;
      }
      prevTs = s.ts;
      _distances.add(distanceKm);
      final e = s.elevation;
      _elevations.add(e ?? double.nan);
      _powers.add(s.humanPowerW);
      if (e != null) {
        elevMin = elevMin == null ? e : math.min(elevMin, e);
        elevMax = elevMax == null ? e : math.max(elevMax, e);
      }
      powerMin = powerMin == null ? s.humanPowerW : math.min(powerMin, s.humanPowerW);
      powerMax = powerMax == null ? s.humanPowerW : math.max(powerMax, s.humanPowerW);
    }
    _totalDistance = distanceKm;
    _viewStart = 0;
    _viewEnd = distanceKm;
    _elevMin = elevMin ?? 0;
    _elevMax = elevMax ?? 1;
    _powerMin = powerMin ?? 0;
    _powerMax = powerMax ?? 1;
    _cursorDist = null;
    _rangeStart = null;
  }

  /// Maps a screen x within [plotLeft, plotRight] to a distance (km).
  double _xToDistance(double x, double plotLeft, double plotRight) {
    if (plotRight <= plotLeft) return _viewStart;
    final t = ((x - plotLeft) / (plotRight - plotLeft)).clamp(0.0, 1.0);
    return _viewStart + t * (_viewEnd - _viewStart);
  }

  /// Finds the sample index whose distance is closest to [km].
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

  void _moveCursorTo(double x, double plotLeft, double plotRight) {
    final km = _xToDistance(x, plotLeft, plotRight);
    final idx = _nearestIndex(km);
    setState(() => _cursorDist = _distances[idx]);
    widget.onCursorChanged(_distances[idx]);
  }

  void _zoomAround(double focalX, double scale, double plotLeft, double plotRight) {
    // Distance under the focal point stays fixed on screen while the window
    // width is divided by [scale].
    final focalKm = _xToDistance(focalX, plotLeft, plotRight);
    final newWidth = ((_viewEnd - _viewStart) / scale).clamp(0.05, _totalDistance);
    var start = focalKm - (focalKm - _viewStart) / scale;
    var end = start + newWidth;
    if (start < 0) {
      start = 0;
      end = newWidth;
    }
    if (end > _totalDistance) {
      end = _totalDistance;
      start = (_totalDistance - newWidth).clamp(0.0, _totalDistance);
    }
    setState(() {
      _viewStart = start;
      _viewEnd = end;
    });
    widget.onViewRangeChanged(_viewStart, _viewEnd);
  }

  void _resetView() {
    setState(() {
      _viewStart = 0;
      _viewEnd = _totalDistance;
      _rangeStart = null;
    });
    widget.onResetView();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final elevColor = colorScheme.primary;
    final powerColor = colorScheme.tertiary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.min(180.0, constraints.maxHeight);
        final width = constraints.maxWidth;
        const plotLeft = 44.0;
        const plotRightPad = 44.0;
        final plotRight = width - plotRightPad;
        const topPad = 10.0;
        const bottomPad = 22.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _moveCursorTo(d.localPosition.dx, plotLeft, plotRight),
          onScaleUpdate: (d) {
            if (d.pointerCount >= 2) {
              // Two-finger pinch zooms the visible window.
              _zoomAround(d.localFocalPoint.dx, d.scale, plotLeft, plotRight);
            } else {
              // Single-pointer drag moves the cursor (scale stays 1.0).
              _moveCursorTo(d.localFocalPoint.dx, plotLeft, plotRight);
            }
          },
          onDoubleTap: _resetView,
          onLongPressStart: (d) {
            final km = _xToDistance(d.localPosition.dx, plotLeft, plotRight);
            if (_rangeStart == null) {
              setState(() => _rangeStart = km);
            } else {
              final start = math.min(_rangeStart!, km);
              final end = math.max(_rangeStart!, km);
              setState(() {
                _viewStart = start;
                _viewEnd = end;
                _rangeStart = null;
              });
              widget.onViewRangeChanged(_viewStart, _viewEnd);
            }
          },
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: colorScheme.surface.withAlpha(204),
              border: Border(top: BorderSide(color: colorScheme.outline.withAlpha(120))),
            ),
            child: CustomPaint(
              size: Size(width, height),
              painter: _GraphPainter(
                distances: _distances,
                elevations: _elevations,
                powers: _powers,
                viewStart: _viewStart,
                viewEnd: _viewEnd,
                cursorDist: _cursorDist,
                rangeStart: _rangeStart,
                showElevation: widget.showElevation,
                showPower: widget.showPower,
                elevMin: _elevMin,
                elevMax: _elevMax,
                powerMin: _powerMin,
                powerMax: _powerMax,
                plotLeft: plotLeft,
                plotRight: plotRight,
                topPad: topPad,
                bottomPad: bottomPad,
                elevColor: elevColor,
                powerColor: powerColor,
                textColor: colorScheme.onSurface,
                gridColor: colorScheme.outline.withAlpha(60),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints the combined Elevation / Power graph for the visible distance window.
class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.distances,
    required this.elevations,
    required this.powers,
    required this.viewStart,
    required this.viewEnd,
    required this.cursorDist,
    required this.rangeStart,
    required this.showElevation,
    required this.showPower,
    required this.elevMin,
    required this.elevMax,
    required this.powerMin,
    required this.powerMax,
    required this.plotLeft,
    required this.plotRight,
    required this.topPad,
    required this.bottomPad,
    required this.elevColor,
    required this.powerColor,
    required this.textColor,
    required this.gridColor,
  });

  final List<double> distances;
  final List<double> elevations;
  final List<double> powers;
  final double viewStart;
  final double viewEnd;
  final double? cursorDist;
  final double? rangeStart;
  final bool showElevation;
  final bool showPower;
  final double elevMin;
  final double elevMax;
  final double powerMin;
  final double powerMax;
  final double plotLeft;
  final double plotRight;
  final double topPad;
  final double bottomPad;
  final Color elevColor;
  final Color powerColor;
  final Color textColor;
  final Color gridColor;

  double get _plotWidth => plotRight - plotLeft;

  double _x(double km, double plotTop, double plotBottom) => plotLeft + ((km - viewStart) / (viewEnd - viewStart).clamp(1e-9, double.infinity)) * _plotWidth;

  double _yElev(double e, double plotTop, double plotBottom) {
    final span = (elevMax - elevMin).clamp(1e-6, double.infinity);
    return plotBottom - ((e - elevMin) / span) * (plotBottom - plotTop);
  }

  double _yPower(double p, double plotTop, double plotBottom) {
    final span = (powerMax - powerMin).clamp(1e-6, double.infinity);
    return plotBottom - ((p - powerMin) / span) * (plotBottom - plotTop);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotTop = topPad;
    final plotBottom = size.height - bottomPad;
    final plotH = plotBottom - plotTop;

    // Gridlines (horizontal).
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plotTop + (plotH * i / 4);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
    }

    // Axis labels.
    final labelStyle = TextStyle(color: textColor, fontSize: 10);
    if (showElevation) {
      final span = (elevMax - elevMin).clamp(1e-6, double.infinity);
      for (var i = 0; i <= 4; i++) {
        final val = elevMax - span * i / 4;
        _drawText(canvas, '${val.round()}', const Offset(2, 0), labelStyle, y: plotTop + plotH * i / 4, alignRight: false);
      }
    }
    if (showPower) {
      final span = (powerMax - powerMin).clamp(1e-6, double.infinity);
      for (var i = 0; i <= 4; i++) {
        final val = powerMax - span * i / 4;
        _drawText(canvas, '${val.round()}', Offset(plotRight + 4, 0), labelStyle, y: plotTop + plotH * i / 4, alignRight: false);
      }
    }

    // Range-select highlight.
    if (rangeStart != null) {
      final x0 = _x(math.min(rangeStart!, viewStart), plotTop, plotBottom);
      final x1 = _x(math.max(rangeStart!, viewEnd), plotTop, plotBottom);
      final hl = Paint()..color = elevColor.withAlpha(40);
      canvas.drawRect(Rect.fromLTRB(x0, plotTop, x1, plotBottom), hl);
    }

    // Elevation profile fill (drawn under the line).
    if (showElevation) _drawElevationFill(canvas, plotTop, plotBottom);

    // Series lines.
    if (showElevation) _drawSeries(canvas, elevations, elevColor, plotTop, plotBottom, _yElev);
    if (showPower) _drawSeries(canvas, powers, powerColor, plotTop, plotBottom, _yPower);

    // Cursor line.
    if (cursorDist != null && cursorDist! >= viewStart && cursorDist! <= viewEnd) {
      final cx = _x(cursorDist!, plotTop, plotBottom);
      final cursorPaint = Paint()
        ..color = textColor.withAlpha(180)
        ..strokeWidth = 3.0;
      canvas.drawLine(Offset(cx, plotTop), Offset(cx, plotBottom), cursorPaint);
      // Dots at the cursor for each visible series.
      final idx = _nearestIndex(cursorDist!);
      if (showElevation && idx < elevations.length && !elevations[idx].isNaN) {
        _drawDot(canvas, Offset(cx, _yElev(elevations[idx], plotTop, plotBottom)), elevColor);
      }
      if (showPower && idx < powers.length) {
        _drawDot(canvas, Offset(cx, _yPower(powers[idx], plotTop, plotBottom)), powerColor);
      }
    }

    // X-axis distance labels (start / end of window).
    final xLabel = TextStyle(color: textColor, fontSize: 10);
    _drawText(canvas, '${viewStart.toStringAsFixed(1)} km', Offset(plotLeft, plotBottom + 4), xLabel);
    _drawText(canvas, '${viewEnd.toStringAsFixed(1)} km', Offset(plotRight, plotBottom + 4), xLabel, alignRight: true);
  }

  int _nearestIndex(double km) {
    if (distances.isEmpty) return 0;
    var lo = 0;
    var hi = distances.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (distances[mid] < km) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0 && (lo == distances.length || (distances[lo] - km) > (km - distances[lo - 1]))) {
      lo -= 1;
    }
    return lo;
  }

  void _drawElevationFill(Canvas canvas, double plotTop, double plotBottom) {
    final paint = Paint()
      ..color = elevColor.withAlpha(40)
      ..style = PaintingStyle.fill;
    Path? path;
    double? lastX;
    var started = false;
    for (var i = 0; i < distances.length; i++) {
      final km = distances[i];
      if (km < viewStart || km > viewEnd) continue;
      final e = elevations[i];
      if (e.isNaN) {
        started = false;
        continue;
      }
      final x = _x(km, plotTop, plotBottom);
      final y = _yElev(e, plotTop, plotBottom);
      if (!started) {
        path = Path()..moveTo(x, plotBottom);
        path.lineTo(x, y);
        started = true;
      } else {
        path!.lineTo(x, y);
      }
      lastX = x;
    }
    if (path != null && lastX != null) {
      path.lineTo(lastX, plotBottom);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawSeries(Canvas canvas, List<double> values, Color color, double plotTop, double plotBottom, double Function(double, double, double) yOf) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    Path? path;
    var started = false;
    for (var i = 0; i < distances.length; i++) {
      final km = distances[i];
      if (km < viewStart || km > viewEnd) continue;
      final v = values[i];
      if (v.isNaN) {
        started = false;
        continue;
      }
      final x = _x(km, plotTop, plotBottom);
      final y = yOf(v, plotTop, plotBottom);
      if (!started) {
        path = Path()..moveTo(x, y);
        started = true;
      } else {
        path!.lineTo(x, y);
      }
    }
    if (path != null) canvas.drawPath(path, paint);
  }

  void _drawDot(Canvas canvas, Offset p, Color color) {
    canvas.drawCircle(p, 3, Paint()..color = color);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style, {bool alignRight = false, double? y}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout();
    var dx = offset.dx;
    if (alignRight) dx = offset.dx - tp.width;
    final dy = y != null ? y - tp.height / 2 : offset.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.viewStart != viewStart ||
      old.viewEnd != viewEnd ||
      old.cursorDist != cursorDist ||
      old.rangeStart != rangeStart ||
      old.showElevation != showElevation ||
      old.showPower != showPower ||
      old.distances != distances ||
      old.elevations != elevations ||
      old.powers != powers;
}
