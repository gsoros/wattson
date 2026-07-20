import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

import '../config/map_config.dart';

/// A semi-transparent Map Settings panel overlaid on the ride map.
///
/// Lets the user configure the map source, the Thunderforest API key, the
/// track stroke color/width, and the graphs overlays. Every
/// change is persisted via [MapConfig] and reported through [onChanged] so the
/// parent map can rebuild immediately.
class MapSettings extends StatefulWidget {
  const MapSettings({super.key, required this.onChanged, required this.onClose});

  /// Called after any setting changes, so the parent can rebuild the map.
  final VoidCallback onChanged;

  /// Called when the user dismisses the overlay (scrim tap or close button).
  final VoidCallback onClose;

  @override
  State<MapSettings> createState() => _MapSettingsState();
}

class _MapSettingsState extends State<MapSettings> {
  final _apiKeyController = TextEditingController(text: MapConfig.thunderforestApiKey);
  Timer? _apiKeySaveTimer;

  @override
  void initState() {
    super.initState();
    _apiKeyController.addListener(_onApiKeyChanged);
  }

  @override
  void dispose() {
    _apiKeySaveTimer?.cancel();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _onApiKeyChanged() {
    final value = _apiKeyController.text;
    _apiKeySaveTimer?.cancel();
    _apiKeySaveTimer = Timer(const Duration(seconds: 1), () {
      MapConfig.setApiKey(value);
      widget.onChanged();
    });
  }

  Future<void> _pickColor() async {
    final initial = Color(MapConfig.strokeColor ?? MapConfig.defaultStrokeColor);
    final picked = await showColorPickerDialog(
      context,
      initial,
      title: const Text('Track color', style: TextStyle(fontSize: 18)),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 0,
      wheelDiameter: 165,
      enableOpacity: false,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.wheel: true,
      },
    );
    if (!mounted) return;
    await MapConfig.setStrokeColor(picked.toARGB32());
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = MapConfig.mapSource;
    final needsKey = source.needsKey;
    final keyMissing = needsKey && MapConfig.thunderforestApiKey.trim().isEmpty;

    return Material(
      color: Colors.black54,
      child: GestureDetector(
        // Tapping the scrim closes the overlay without changing settings.
        onTap: () => widget.onClose(),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Absorb taps inside the card.
            child: Container(
              margin: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withAlpha(160),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Map Settings', style: theme.textTheme.titleLarge),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: () => widget.onClose()),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Map source selector.
                    Text('Map source', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    DropdownButton<MapSource>(
                      value: source,
                      isExpanded: true,
                      items: [for (final s in MapSource.values) DropdownMenuItem(value: s, child: Text(s.label))],
                      onChanged: (s) async {
                        if (s == null) return;
                        await MapConfig.setMapSource(s);
                        widget.onChanged();
                        setState(() {});
                      },
                    ),
                    if (keyMissing)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'This source needs a Thunderforest API key (enter one below).',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Thunderforest API key.
                    Text('Thunderforest API key', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(hintText: 'Paste your key here', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
                    ),
                    const SizedBox(height: 4),
                    Text('Get a free key at https://www.thunderforest.com/pricing/', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 16),

                    // Track stroke color.
                    Text('Track color', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _pickColor,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(MapConfig.strokeColor ?? MapConfig.defaultStrokeColor),
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Track stroke width.
                    Text('Track width: ${MapConfig.strokeWidth.toStringAsFixed(1)} px', style: theme.textTheme.titleSmall),
                    Slider(
                      value: MapConfig.strokeWidth,
                      min: 1,
                      max: 12,
                      divisions: 22,
                      label: MapConfig.strokeWidth.toStringAsFixed(1),
                      onChanged: (v) async {
                        await MapConfig.setStrokeWidth(v);
                        widget.onChanged();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),

                    // Graph metric slot 1 (left axis, filled).
                    Text('Graph metric 1', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    DropdownButton<GraphMetric>(
                      value: MapConfig.graphMetric1,
                      isExpanded: true,
                      items: [
                        for (final m in GraphMetric.values)
                          if (m == GraphMetric.none || m != MapConfig.graphMetric2) DropdownMenuItem(value: m, child: Text(m.label)),
                      ],
                      onChanged: (m) async {
                        if (m == null) return;
                        await MapConfig.setGraphMetric1(m);
                        widget.onChanged();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),

                    // Graph metric slot 2 (right axis, line).
                    Text('Graph metric 2', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    DropdownButton<GraphMetric>(
                      value: MapConfig.graphMetric2,
                      isExpanded: true,
                      items: [
                        for (final m in GraphMetric.values)
                          if (m == GraphMetric.none || m != MapConfig.graphMetric1) DropdownMenuItem(value: m, child: Text(m.label)),
                      ],
                      onChanged: (m) async {
                        if (m == null) return;
                        await MapConfig.setGraphMetric2(m);
                        widget.onChanged();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
