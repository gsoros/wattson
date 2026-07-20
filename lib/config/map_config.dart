import 'package:shared_preferences/shared_preferences.dart';

/// Tile sources for the ride Map tab.
///
/// The base source is OpenStreetMap (no key required). When a Thunderforest
/// API key is configured, the user may pick one of several Thunderforest styles
/// (all sharing that single key). The key is persisted via [SharedPreferences]
/// and loaded at startup by [MapConfig.load].
///
/// See https://www.thunderforest.com/pricing/ for a free API key.
enum MapSource {
  /// Plain OpenStreetMap raster tiles. No API key required.
  osm('OpenStreetMap', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', '© OpenStreetMap contributors'),

  /// Thunderforest "Cycle" style — cycling-optimized OSM rendering.
  thunderforestCycle('Thunderforest Cycle', 'https://tile.thunderforest.com/cycle/{z}/{x}/{y}.png', '© Thunderforest, © OpenStreetMap contributors'),

  /// Thunderforest "Outdoors" style — topographic, good for mixed terrain.
  thunderforestOutdoors('Thunderforest Outdoors', 'https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png', '© Thunderforest, © OpenStreetMap contributors'),

  /// Thunderforest "Transport" style — emphasizes roads and transit.
  thunderforestTransport(
    'Thunderforest Transport',
    'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png',
    '© Thunderforest, © OpenStreetMap contributors',
  );

  const MapSource(this.label, this._template, this._attribution);

  /// Human-readable label for the source selector.
  final String label;

  final String _template;

  final String _attribution;

  /// Whether this source requires a Thunderforest API key.
  bool get needsKey => this != MapSource.osm;

  /// The tile URL template for this source. For Thunderforest sources the API
  /// key is appended as a query parameter when one is configured.
  String template(String apiKey) {
    if (!needsKey) return _template;
    final key = apiKey.trim();
    if (key.isEmpty) return _template; // Will fail to load tiles; UI warns.
    return '$_template?apikey=$key';
  }

  String attribution(String apiKey) => needsKey && apiKey.trim().isNotEmpty ? _attribution : '© OpenStreetMap contributors';
}

/// Persistent map configuration for the ride Map tab.
///
/// Holds the Thunderforest API key, the selected [MapSource], the track stroke
/// color/width, and the Elevation/Power overlay toggles. All values are stored
/// in [SharedPreferences] and loaded once at startup by [MapConfig.load].
class MapConfig {
  MapConfig._();

  static const String _prefsKeyApi = 'thunderforest_api_key';
  static const String _prefsKeySource = 'map_source';
  static const String _prefsKeyStrokeColor = 'map_stroke_color';
  static const String _prefsKeyStrokeWidth = 'map_stroke_width';
  static const String _prefsKeyElevationOverlay = 'map_elevation_overlay';
  static const String _prefsKeyPowerOverlay = 'map_power_overlay';

  /// The Thunderforest API key, loaded at runtime. Empty means "no key".
  static String thunderforestApiKey = '';

  /// The selected map source. Defaults to plain OSM (no key needed).
  static MapSource mapSource = MapSource.osm;

  /// Default track stroke color (ARGB int). A vivid orange chosen for good
  /// contrast against the greens of rural maps and the greys of OSM.
  static const int defaultStrokeColor = 0xFFFF8C00;

  /// Track stroke color as an ARGB int. Defaults to [defaultStrokeColor].
  static int? strokeColor = defaultStrokeColor;

  /// Track stroke width in logical pixels.
  static double strokeWidth = 4.0;

  /// Whether the Elevation series is shown in the bottom overlay graph.
  static bool elevationOverlay = true;

  /// Whether the Power series is shown in the bottom overlay graph.
  static bool powerOverlay = true;

  /// Loads all persisted values. Call once at startup (e.g. in [main]).
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    thunderforestApiKey = prefs.getString(_prefsKeyApi) ?? '';
    final sourceName = prefs.getString(_prefsKeySource);
    mapSource = MapSource.values.where((s) => s.name == sourceName).firstOrNull ?? MapSource.osm;
    strokeColor = prefs.getInt(_prefsKeyStrokeColor) ?? defaultStrokeColor;
    strokeWidth = prefs.getDouble(_prefsKeyStrokeWidth) ?? 4.0;
    elevationOverlay = prefs.getBool(_prefsKeyElevationOverlay) ?? true;
    powerOverlay = prefs.getBool(_prefsKeyPowerOverlay) ?? true;
  }

  /// Persists [key] and updates the in-memory value.
  static Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    thunderforestApiKey = trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefsKeyApi);
    } else {
      await prefs.setString(_prefsKeyApi, trimmed);
    }
  }

  /// Persists the selected [MapSource].
  static Future<void> setMapSource(MapSource source) async {
    mapSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeySource, source.name);
  }

  /// Persists the track stroke color (ARGB int, or null for theme primary).
  static Future<void> setStrokeColor(int? color) async {
    strokeColor = color;
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(_prefsKeyStrokeColor);
    } else {
      await prefs.setInt(_prefsKeyStrokeColor, color);
    }
  }

  /// Persists the track stroke width in logical pixels.
  static Future<void> setStrokeWidth(double width) async {
    strokeWidth = width;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKeyStrokeWidth, width);
  }

  /// Persists the Elevation overlay toggle.
  static Future<void> setElevationOverlay(bool enabled) async {
    elevationOverlay = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyElevationOverlay, enabled);
  }

  /// Persists the Power overlay toggle.
  static Future<void> setPowerOverlay(bool enabled) async {
    powerOverlay = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyPowerOverlay, enabled);
  }

  /// The tile template actually used at runtime for the active source.
  static String get tileTemplate => mapSource.template(thunderforestApiKey);

  /// Required attribution string for the active source.
  static String get attribution => mapSource.attribution(thunderforestApiKey);

  /// Application package id, sent as the tile `User-Agent` per OSM policy.
  static const String userAgentPackageName = 'org.gsoros.wattson';
}
