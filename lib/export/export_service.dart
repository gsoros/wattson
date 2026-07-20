import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import 'gpx_serializer.dart';

/// Writes a ride's samples to a GPX file and opens the OS share sheet.
///
/// The file is written to the app's temporary directory (cleared on OS
/// reclaim) so no persistent copy is left behind. Returns the [ShareResult]
/// so callers can react to success/dismissal if they wish.
Future<ShareResult> shareRideGpx({required Ride ride, required List<Sample> samples}) async {
  final gpx = buildGpx(ride: ride, samples: samples);

  final dir = await getTemporaryDirectory();
  final safeName = (ride.title?.isNotEmpty == true ? ride.title! : 'ride-${ride.id}').replaceAll(RegExp(r'[^\w\-]+'), '_');
  final file = File('${dir.path}/$safeName.gpx');
  await file.writeAsString(gpx);

  final subject = ride.title?.isNotEmpty == true ? ride.title! : 'Wattson ride';
  return SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, name: '$safeName.gpx', mimeType: 'application/gpx+xml')],
      subject: subject,
      text: subject,
    ),
  );
}
