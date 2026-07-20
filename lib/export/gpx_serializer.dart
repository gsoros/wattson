import 'dart:convert';

import '../data/database.dart';

/// Builds a GPX 1.1 document from a ride's telemetry samples.
///
/// Standard Garmin TrackPointExtension (`gpxtpx`) carries the channels the
/// major platforms (Strava, Garmin, RideWithGPS) graph automatically:
/// `hr`, `cad`, `distance`, `speed`, and `watts` (human power).
///
/// Motor power has no standard GPX field, so it is written as a custom
/// `<wattson:motorWatts>` element under the `wattson` namespace. Host platforms
/// ignore unknown namespaces, but the in-app Graphs tab (and tools like
/// GoldenCheetah configured to read it) can use it.
String buildGpx({required Ride ride, required List<Sample> samples}) {
  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln(
    '<gpx version="1.1" creator="Wattson" '
    'xmlns="http://www.topografix.com/GPX/1/1" '
    'xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" '
    'xmlns:wattson="https://wattson.local/gpx/v1">',
  );

  // Metadata: name from the ride title (or its start date as a fallback).
  final name = ride.title?.isNotEmpty == true ? ride.title! : _iso(ride.startTime);
  buffer.writeln('  <metadata>');
  buffer.writeln('    <name>${_escape(name)}</name>');
  buffer.writeln('    <time>${_iso(ride.startTime)}</time>');
  buffer.writeln('  </metadata>');

  buffer.writeln('  <trk>');
  buffer.writeln('    <name>${_escape(name)}</name>');
  buffer.writeln('    <trkseg>');

  // Running distance accumulator (km) so each point carries cumulative distance.
  double distanceKm = 0;
  DateTime? prevTs;
  for (final s in samples) {
    if (s.lat == null || s.lon == null) continue; // Skip GPS-less points.

    if (prevTs != null) {
      final dtH = s.ts.difference(prevTs).inMilliseconds / 3600000.0;
      if (dtH > 0) distanceKm += s.speedKmh * dtH;
    }
    prevTs = s.ts;

    buffer.writeln('      <trkpt lat="${_num(s.lat!)}" lon="${_num(s.lon!)}">');
    if (s.elevation != null) buffer.writeln('        <ele>${_num(s.elevation!)}</ele>');
    buffer.writeln('        <time>${_iso(s.ts)}</time>');
    buffer.writeln('        <extensions>');
    buffer.writeln('          <gpxtpx:TrackPointExtension>');
    if (s.hrBpm != 0) buffer.writeln('            <gpxtpx:hr>${s.hrBpm}</gpxtpx:hr>');
    buffer.writeln('            <gpxtpx:cad>${s.cadenceRpm}</gpxtpx:cad>');
    buffer.writeln('            <gpxtpx:distance>${_num(distanceKm * 1000)}</gpxtpx:distance>');
    buffer.writeln('            <gpxtpx:speed>${_num(s.speedKmh / 3.6)}</gpxtpx:speed>');
    buffer.writeln('            <gpxtpx:watts>${s.humanPowerW.round()}</gpxtpx:watts>');
    buffer.writeln('          </gpxtpx:TrackPointExtension>');
    buffer.writeln('          <wattson:motorWatts>${s.motorPowerW.round()}</wattson:motorWatts>');
    buffer.writeln('        </extensions>');
    buffer.writeln('      </trkpt>');
  }

  buffer.writeln('    </trkseg>');
  buffer.writeln('  </trk>');
  buffer.writeln('</gpx>');
  return buffer.toString();
}

String _iso(DateTime dt) => dt.toUtc().toIso8601String();

String _num(double v) => v.toStringAsFixed(6);

String _escape(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);
