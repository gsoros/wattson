/// Tile sources for the ride Map tab.
///
/// Primary source is OpenCycleMap (a Thunderforest style built on OpenStreetMap
/// data), which is the most cycling-appropriate style. It requires a free API
/// key — sign up at https://www.thunderforest.com/pricing/ and paste it below.
///
/// If no key is set, we fall back to the standard OpenStreetMap tile server,
/// which needs no key but has a stricter usage policy (keep to interactive,
/// low-volume use). Both sources are OSM-based and non-commercial.
class MapConfig {
  MapConfig._();

  /// Thunderforest API key for OpenCycleMap tiles.
  ///
  /// Leave empty to use the plain OSM fallback. Get a free key at
  /// https://www.thunderforest.com/pricing/.
  static const String thunderforestApiKey = '';

  /// OpenCycleMap (Thunderforest) raster tile template. `{z}/{x}/{y}` are
  /// substituted by flutter_map; the API key is appended as a query param.
  static const String openCycleMapTemplate = 'https://tile.thunderforest.com/cycle/{z}/{x}/{y}.png?apikey=$thunderforestApiKey';

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
