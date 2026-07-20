import 'package:shared_preferences/shared_preferences.dart';

/// Tile sources for the ride Map tab.
///
/// Primary source is OpenCycleMap (a Thunderforest style built on OpenStreetMap
/// data), which is the most cycling-appropriate style. It requires a free API
/// key — sign up at https://www.thunderforest.com/pricing/ and enter it in
/// Settings. The key is persisted via [SharedPreferences] and loaded at startup
/// by [MapConfig.load].
///
/// If no key is set, we fall back to the standard OpenStreetMap tile server,
/// which needs no key but has a stricter usage policy (keep to interactive,
/// low-volume use). Both sources are OSM-based and non-commercial.
class MapConfig {
  MapConfig._();

  /// [SharedPreferences] key under which the Thunderforest API key is stored.
  static const String _prefsKey = 'thunderforest_api_key';

  /// The Thunderforest API key for OpenCycleMap tiles, loaded at runtime.
  ///
  /// Empty means "use the plain OSM fallback". Get a free key at
  /// https://www.thunderforest.com/pricing/.
  static String thunderforestApiKey = '';

  /// Loads the persisted API key. Call once at startup (e.g. in [main]).
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    thunderforestApiKey = prefs.getString(_prefsKey) ?? '';
  }

  /// Persists [key] and updates the in-memory value.
  static Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    thunderforestApiKey = trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, trimmed);
    }
  }

  /// OpenCycleMap (Thunderforest) raster tile template. `{z}/{x}/{y}` are
  /// substituted by flutter_map; the API key is appended as a query param.
  static String get openCycleMapTemplate => 'https://tile.thunderforest.com/cycle/{z}/{x}/{y}.png?apikey=$thunderforestApiKey';

  /// Standard OpenStreetMap tile template (no key required).
  static const String openStreetMapTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// The tile template actually used at runtime: OpenCycleMap when a key is
  /// configured, otherwise plain OSM.
  static String get tileTemplate => thunderforestApiKey.isEmpty ? openStreetMapTemplate : openCycleMapTemplate;

  /// Required attribution string for the active source.
  static String get attribution {
    if (thunderforestApiKey.isEmpty) {
      return '© OpenStreetMap contributors';
    }
    return '© Thunderforest, © OpenStreetMap contributors';
  }

  /// Application package id, sent as the tile `User-Agent` per OSM policy.
  static const String userAgentPackageName = 'app.wattson.wattson';
}
