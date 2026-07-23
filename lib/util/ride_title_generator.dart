import '../data/database.dart';

/// Generates a cheeky or motivational ride title from the ride's data and
/// computed stats.
///
/// Pure function: given the same [Ride] it always returns the same title, so
/// it is safe to call from build methods. Intended as a *suggestion* the user
/// can accept or override via the editable title field.
///
/// The logic layers a few heuristics:
///   1. Time of day  -> "Early Morning", "Afternoon", "Moonlit", ...
///   2. Distance     -> "Spin", "Century", "Epic"
///   3. Effort       -> human power / assist ratio / elevation
String generateRideTitle(Ride ride) {
  final parts = <String>[];

  // --- Time of day (prefix) ---
  final h = ride.startTime.hour;
  String timeOfDay;
  if (h < 5) {
    timeOfDay = 'Moonlit';
  } else if (h < 11) {
    timeOfDay = 'Early Morning';
  } else if (h < 14) {
    timeOfDay = 'Midday';
  } else if (h < 18) {
    timeOfDay = 'Afternoon';
  } else if (h < 22) {
    timeOfDay = 'Evening';
  } else {
    timeOfDay = 'Late Night';
  }
  parts.add(timeOfDay);

  // --- Distance bucket (noun) ---
  final km = ride.distanceKm;
  String noun;
  if (km >= 100) {
    noun = 'Century';
  } else if (km >= 60) {
    noun = 'Epic';
  } else if (km >= 30) {
    noun = 'Tour';
  } else if (km >= 12) {
    noun = 'Ride';
  } else if (km >= 4) {
    noun = 'Spin';
  } else {
    noun = 'Loop';
  }

  // --- Effort flavor (suffix / override) ---
  final avgHuman = ride.avgHumanPowerW ?? 0;
  final maxHuman = ride.maxHumanPowerW ?? 0;
  final assist = ride.assistRatio;
  final climb = ride.elevationGainM;

  if (avgHuman >= 180 || maxHuman >= 320) {
    // Hard effort regardless of distance.
    return '$timeOfDay ${_strongNoun(noun)}';
  }
  if (assist != null && assist < 0.4 && km >= 12) {
    // Motor did most of the work.
    return 'Assisted $noun';
  }
  if (climb >= 800 && km >= 12) {
    return '$timeOfDay Climb';
  }
  if (avgHuman > 0 && avgHuman < 100 && km < 12) {
    // Low effort, short ride.
    return 'Lazy ${_shortNoun(noun)}';
  }
  if (avgHuman >= 230) {
    return 'Superhuman $noun';
  }

  parts.add(noun);
  return parts.join(' ');
}

/// Upgrades a distance noun to something punchier for hard efforts.
String _strongNoun(String noun) {
  switch (noun) {
    case 'Loop':
    case 'Spin':
      return 'Sprint';
    case 'Ride':
    case 'Tour':
      return 'Grind';
    case 'Epic':
      return 'Assault';
    case 'Century':
      return 'Enduro';
    default:
      return noun;
  }
}

/// Downgrades a distance noun for lazy/short rides.
String _shortNoun(String noun) {
  switch (noun) {
    case 'Century':
    case 'Epic':
    case 'Tour':
      return 'Roll';
    default:
      return noun;
  }
}
