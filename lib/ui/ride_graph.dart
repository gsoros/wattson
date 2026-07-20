import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/map_config.dart';
import '../data/database.dart';

/// A semi-transparent combined overlay graph drawn at the bottom of the ride
/// map, plotting any two [GraphMetric]s in two slots.
///
/// The horizontal axis is cumulative distance (km), integrated from speed × Δt
/// (the same formula used by the GPX exporter). The vertical axis shows the two
/// selected metrics as two overlaid series: slot 1 (left axis, filled) and
/// slot 2 (right axis, line).
///
/// Interaction:
///  * Tap / drag  → moves the cursor to the nearest sample; the parent moves a
///    dot on the map to the matching GPS fix.
///  * Pinch        → zooms the visible distance window around the focal point;
///    the parent zooms the map to the same range.
///  * Long-press + horizontal drag → defines a range: the long-press anchors
///    the start, the drag extends the end; on release the view zooms to that
///    range (a live highlight shows the selection while dragging).
///  * Double-tap   → resets the view to the full ride range.
class RideGraph extends StatefulWidget {
  const RideGraph({
    super.key,
    required this.samples,
    required this.metric1,
    required this.metric2,
    required this.color1,
    required this.color2,
    required this.onCursorChanged,
    required this.onViewRangeChanged,
    required this.onResetView,
  });

  /// GPS-valid ride samples (lat/lon non-null), in time order.
  final List<Sample> samples;

  /// Metric plotted in the first (left, filled) slot.
  final GraphMetric metric1;

  /// Metric plotted in the second (right, line) slot.
  final GraphMetric metric2;

  /// Color for the first slot's series/fill.
  final Color color1;

  /// Color for the second slot's series.
  final Color color2;

  /// Called with the distance (km) of the sample under the cursor.
  final ValueChanged<double> onCursorChanged;

  /// Called when the visible distance window changes (pinch / range select).
  final void Function(double startKm, double endKm) onViewRangeChanged;

  /// Called on double-tap to reset the view to the full ride.
  final VoidCallback onResetView;

  @override
  State<RideGraph> createState() => _RideGraphState();
}

class _RideGraphState extends State<RideGraph> {
  // Precomputed per-sample series, aligned to [widget.samples].
  // Mutable (not `late final`) because [_computeSeries] may run again when the
  // widget is updated with new samples.
  List<double> _distances = const []; // cumulative km
  List<double> _series1 = const []; // metric1 values (NaN where unavailable)
  List<double> _series2 = const []; // metric2 values
  double _totalDistance = 0;
  double _min1 = 0;
  double _max1 = 1;
  double _min2 = 0;
  double _max2 = 1;

  // Visible distance window (km).
  double _viewStart = 0;
  double _viewEnd = 0;

  // Cursor distance (km), or null when not yet placed.
  double? _cursorDist;

  // Range-select state: set by a long-press (anchor) and updated by the
  // subsequent horizontal drag. Both are non-null only while selecting.
  double? _rangeStart;
  double? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _computeSeries();
  }

  @override
  void didUpdateWidget(covariant RideGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.samples != widget.samples || oldWidget.metric1 != widget.metric1 || oldWidget.metric2 != widget.metric2) {
      _computeSeries();
    }
  }

  void _computeSeries() {
    final samples = widget.samples;
    _distances = [];
    _series1 = [];
    _series2 = [];
    double distanceKm = 0;
    DateTime? prevTs;
    double? min1;
    double? max1;
    double? min2;
    double? max2;
    for (final s in samples) {
      if (prevTs != null) {
        final dtH = s.ts.difference(prevTs).inMilliseconds / 3600000.0;
        if (dtH > 0) distanceKm += s.speedKmh * dtH;
      }
      prevTs = s.ts;
      _distances.add(distanceKm);
      final v1 = widget.metric1.value(s);
      final v2 = widget.metric2.value(s);
      _series1.add(v1);
      _series2.add(v2);
      if (!v1.isNaN) {
        min1 = min1 == null ? v1 : math.min(min1, v1);
        max1 = max1 == null ? v1 : math.max(max1, v1);
      }
      if (!v2.isNaN) {
        min2 = min2 == null ? v2 : math.min(min2, v2);
        max2 = max2 == null ? v2 : math.max(max2, v2);
      }
    }
    _totalDistance = distanceKm;
    _viewStart = 0;
    _viewEnd = distanceKm;
    _min1 = min1 ?? 0;
    _max1 = max1 ?? 1;
    _min2 = min2 ?? 0;
    _max2 = max2 ?? 1;
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
      _rangeEnd = null;
    });
    widget.onResetView();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.min(150.0, constraints.maxHeight);
        final width = constraints.maxWidth;
        const plotLeft = 24.0;
        const plotRightPad = 24.0;
        final plotRight = width - plotRightPad;
        const topPad = 16.0;
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
            // Anchor the range at the long-press point; the following
            // horizontal drag extends it.
            final km = _xToDistance(d.localPosition.dx, plotLeft, plotRight);
            setState(() {
              _rangeStart = km;
              _rangeEnd = km;
            });
          },
          onLongPressMoveUpdate: (d) {
            if (_rangeStart == null) return;
            setState(() => _rangeEnd = _xToDistance(d.localPosition.dx, plotLeft, plotRight));
          },
          onLongPressEnd: (d) {
            if (_rangeStart == null || _rangeEnd == null) return;
            final start = math.min(_rangeStart!, _rangeEnd!);
            final end = math.max(_rangeStart!, _rangeEnd!);
            setState(() {
              _viewStart = start;
              _viewEnd = end;
              _rangeStart = null;
              _rangeEnd = null;
            });
            widget.onViewRangeChanged(_viewStart, _viewEnd);
          },
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: colorScheme.surface.withAlpha(180),
              border: Border(top: BorderSide(color: colorScheme.outline.withAlpha(120))),
            ),
            child: CustomPaint(
              size: Size(width, height),
              painter: _GraphPainter(
                distances: _distances,
                viewStart: _viewStart,
                viewEnd: _viewEnd,
                cursorDist: _cursorDist,
                rangeStart: _rangeStart,
                rangeEnd: _rangeEnd,
                metric1: widget.metric1,
                metric2: widget.metric2,
                series1: _series1,
                series2: _series2,
                min1: _min1,
                max1: _max1,
                min2: _min2,
                max2: _max2,
                plotLeft: plotLeft,
                plotRight: plotRight,
                topPad: topPad,
                bottomPad: bottomPad,
                color1: widget.color1,
                color2: widget.color2,
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
    required this.viewStart,
    required this.viewEnd,
    required this.cursorDist,
    required this.rangeStart,
    required this.rangeEnd,
    required this.metric1,
    required this.metric2,
    required this.series1,
    required this.series2,
    required this.min1,
    required this.max1,
    required this.min2,
    required this.max2,
    required this.plotLeft,
    required this.plotRight,
    required this.topPad,
    required this.bottomPad,
    required this.color1,
    required this.color2,
    required this.textColor,
    required this.gridColor,
  });

  final List<double> distances;
  final double viewStart;
  final double viewEnd;
  final double? cursorDist;
  final double? rangeStart;
  final double? rangeEnd;
  final GraphMetric metric1;
  final GraphMetric metric2;
  final List<double> series1;
  final List<double> series2;
  final double min1;
  final double max1;
  final double min2;
  final double max2;
  final double plotLeft;
  final double plotRight;
  final double topPad;
  final double bottomPad;
  final Color color1;
  final Color color2;
  final Color textColor;
  final Color gridColor;

  double get _plotWidth => plotRight - plotLeft;

  double _x(double km, double plotTop, double plotBottom) => plotLeft + ((km - viewStart) / (viewEnd - viewStart).clamp(1e-9, double.infinity)) * _plotWidth;

  double _y1(double v, double plotTop, double plotBottom) {
    final span = (max1 - min1).clamp(1e-6, double.infinity);
    return plotBottom - ((v - min1) / span) * (plotBottom - plotTop);
  }

  double _y2(double v, double plotTop, double plotBottom) {
    final span = (max2 - min2).clamp(1e-6, double.infinity);
    return plotBottom - ((v - min2) / span) * (plotBottom - plotTop);
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

    // Axis labels + numeric ticks, colored per slot (skipped when a slot is
    // "None", so it contributes no axis or series to the graph).
    final show1 = metric1 != GraphMetric.none;
    final show2 = metric2 != GraphMetric.none;
    final labelStyle1 = TextStyle(color: color1, fontSize: 10);
    final labelStyle2 = TextStyle(color: color2, fontSize: 10);
    final unit1 = metric1.unit.isNotEmpty ? ' (${metric1.unit})' : '';
    final unit2 = metric2.unit.isNotEmpty ? ' (${metric2.unit})' : '';
    if (show1) {
      _drawText(canvas, '${metric1.label}$unit1', const Offset(22, 0), labelStyle1, y: plotTop - 2);
      final span1 = (max1 - min1).clamp(1e-6, double.infinity);
      for (var i = 0; i <= 4; i++) {
        final val1 = max1 - span1 * i / 4;
        _drawText(canvas, '${val1.round()}', const Offset(2, 0), labelStyle1, y: plotTop + plotH * i / 4, alignRight: false);
      }
    }
    if (show2) {
      _drawText(canvas, '${metric2.label}$unit2', Offset(plotRight, 0), labelStyle2, y: plotTop - 2, alignRight: true);
      final span2 = (max2 - min2).clamp(1e-6, double.infinity);
      for (var i = 0; i <= 4; i++) {
        final val2 = max2 - span2 * i / 4;
        _drawText(canvas, '${val2.round()}', Offset(plotRight + 4, 0), labelStyle2, y: plotTop + plotH * i / 4, alignRight: false);
      }
    }

    // Range-select highlight (live while long-pressing + dragging).
    if (rangeStart != null && rangeEnd != null) {
      final lo = math.min(rangeStart!, rangeEnd!);
      final hi = math.max(rangeStart!, rangeEnd!);
      final x0 = _x(lo, plotTop, plotBottom);
      final x1 = _x(hi, plotTop, plotBottom);
      final hl = Paint()..color = color1.withAlpha(40);
      canvas.drawRect(Rect.fromLTRB(x0, plotTop, x1, plotBottom), hl);
    }

    // Slot 1 fill (under its line).
    if (show1) _drawFill(canvas, plotTop, plotBottom);

    // Series lines.
    if (show1) _drawSeries(canvas, series1, color1, plotTop, plotBottom, _y1);
    if (show2) _drawSeries(canvas, series2, color2, plotTop, plotBottom, _y2);

    // Cursor line.
    if (cursorDist != null && cursorDist! >= viewStart && cursorDist! <= viewEnd) {
      final cx = _x(cursorDist!, plotTop, plotBottom);
      final cursorPaint = Paint()
        ..color = textColor.withAlpha(180)
        ..strokeWidth = 3.0;
      canvas.drawLine(Offset(cx, plotTop), Offset(cx, plotBottom), cursorPaint);
      // Dots at the cursor for each visible series.
      final idx = _nearestIndex(cursorDist!);
      if (show1 && idx < series1.length && !series1[idx].isNaN) {
        _drawDot(canvas, Offset(cx, _y1(series1[idx], plotTop, plotBottom)), color1);
      }
      if (show2 && idx < series2.length && !series2[idx].isNaN) {
        _drawDot(canvas, Offset(cx, _y2(series2[idx], plotTop, plotBottom)), color2);
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

  void _drawFill(Canvas canvas, double plotTop, double plotBottom) {
    final paint = Paint()
      ..color = color1.withAlpha(40)
      ..style = PaintingStyle.fill;
    Path? path;
    double? lastX;
    var started = false;
    for (var i = 0; i < distances.length; i++) {
      final km = distances[i];
      if (km < viewStart || km > viewEnd) continue;
      final v = series1[i];
      if (v.isNaN) {
        started = false;
        continue;
      }
      final x = _x(km, plotTop, plotBottom);
      final y = _y1(v, plotTop, plotBottom);
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

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style, {bool alignRight = false, bool alignCenter = false, double? y}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout();
    var dx = offset.dx;
    if (alignRight) dx = offset.dx - tp.width;
    if (alignCenter) dx = offset.dx - tp.width / 2;
    final dy = y != null ? y - tp.height / 2 : offset.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.viewStart != viewStart ||
      old.viewEnd != viewEnd ||
      old.cursorDist != cursorDist ||
      old.rangeStart != rangeStart ||
      old.rangeEnd != rangeEnd ||
      old.metric1 != metric1 ||
      old.metric2 != metric2 ||
      old.distances != distances ||
      old.series1 != series1 ||
      old.series2 != series2;
}
