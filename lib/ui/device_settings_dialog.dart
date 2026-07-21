import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../ble/nus_protocol.dart';
import '../providers/ble_provider.dart';
import '../providers/device_config_provider.dart';

/// Full-screen dialog for configuring the connected ORD Dash over NUS.
///
/// Shows a form with all configurable fields. Fetches current values on open,
/// sends commands to the Dash on submit, and updates local state on success.
class DeviceSettingsDialog extends ConsumerStatefulWidget {
  const DeviceSettingsDialog({super.key});

  @override
  ConsumerState<DeviceSettingsDialog> createState() => _DeviceSettingsDialogState();
}

class _DeviceSettingsDialogState extends ConsumerState<DeviceSettingsDialog> {
  // -- Text editing controllers --
  final _hostnameCtrl = TextEditingController();
  final _wifiSsidCtrl = TextEditingController();
  final _wifiPasswordCtrl = TextEditingController();
  final _batteryCtrl = TextEditingController();

  // -- Focus nodes for blur detection --
  final _hostnameFocus = FocusNode();
  final _wifiSsidFocus = FocusNode();
  final _wifiPasswordFocus = FocusNode();
  final _batteryFocus = FocusNode();

  // -- Dirty tracking: whether text was changed but not submitted --
  final _dirty = <DeviceConfigField, bool>{};

  bool _fetching = false;
  bool _disconnected = false;

  @override
  void initState() {
    super.initState();
    _hostnameFocus.addListener(_onHostnameBlur);
    _wifiSsidFocus.addListener(_onWifiSsidBlur);
    _wifiPasswordFocus.addListener(_onWifiPasswordBlur);
    _batteryFocus.addListener(_onBatteryBlur);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAll());
  }

  @override
  void dispose() {
    _hostnameCtrl.dispose();
    _wifiSsidCtrl.dispose();
    _wifiPasswordCtrl.dispose();
    _batteryCtrl.dispose();
    _hostnameFocus.dispose();
    _wifiSsidFocus.dispose();
    _wifiPasswordFocus.dispose();
    _batteryFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _fetching = true);
    await ref.read(deviceConfigProvider.notifier).fetchAll();
    _syncFromState();
    setState(() => _fetching = false);
  }

  /// Copy values from [DeviceConfig] into the text controllers.
  void _syncFromState() {
    final config = ref.read(deviceConfigProvider).config;
    if (config.hostname != null && _hostnameCtrl.text != config.hostname) {
      _hostnameCtrl.text = config.hostname!;
    }
    if (config.wifiSsid != null && _wifiSsidCtrl.text != config.wifiSsid) {
      _wifiSsidCtrl.text = config.wifiSsid!;
    }
    if (config.wifiPassword != null && _wifiPasswordCtrl.text != config.wifiPassword) {
      _wifiPasswordCtrl.text = config.wifiPassword!;
    }
    if (config.batteryCapacityWh != null) {
      final text = config.batteryCapacityWh.toString();
      if (_batteryCtrl.text != text) _batteryCtrl.text = text;
    }
  }

  // ---------------------------------------------------------------------------
  // Blur handlers — mark dirty if changed but not submitted
  // ---------------------------------------------------------------------------

  void _onHostnameBlur() {
    if (!_hostnameFocus.hasFocus) {
      final config = ref.read(deviceConfigProvider).config;
      if (_hostnameCtrl.text.trim() != (config.hostname ?? '')) {
        _setDirty(DeviceConfigField.hostname, true);
      }
    }
  }

  void _onWifiSsidBlur() {
    if (!_wifiSsidFocus.hasFocus) {
      final config = ref.read(deviceConfigProvider).config;
      if (_wifiSsidCtrl.text.trim() != (config.wifiSsid ?? '')) {
        _setDirty(DeviceConfigField.wifiSsid, true);
      }
    }
  }

  void _onWifiPasswordBlur() {
    if (!_wifiPasswordFocus.hasFocus) {
      final config = ref.read(deviceConfigProvider).config;
      if (_wifiPasswordCtrl.text.trim() != (config.wifiPassword ?? '')) {
        _setDirty(DeviceConfigField.wifiPassword, true);
      }
    }
  }

  void _onBatteryBlur() {
    if (!_batteryFocus.hasFocus) {
      final config = ref.read(deviceConfigProvider).config;
      if (_batteryCtrl.text.trim() != (config.batteryCapacityWh?.toString() ?? '')) {
        _setDirty(DeviceConfigField.batteryCapacity, true);
      }
    }
  }

  void _setDirty(DeviceConfigField field, bool dirty) {
    if (_dirty[field] != dirty) {
      setState(() => _dirty[field] = dirty);
    }
  }

  void _clearDirty(DeviceConfigField field) {
    if (_dirty[field] == true) {
      setState(() => _dirty.remove(field));
    }
  }

  // ---------------------------------------------------------------------------
  // Submit handlers
  // ---------------------------------------------------------------------------

  Future<void> _submitHostname() async {
    final value = _hostnameCtrl.text.trim();
    if (value.isEmpty) {
      _showError('Hostname cannot be empty');
      return;
    }
    await ref.read(deviceConfigProvider.notifier).setHostname(value);
    _clearDirty(DeviceConfigField.hostname);
  }

  Future<void> _submitWifiSsid() async {
    final value = _wifiSsidCtrl.text.trim();
    await ref.read(deviceConfigProvider.notifier).setWifiSsid(value);
    _clearDirty(DeviceConfigField.wifiSsid);
  }

  Future<void> _submitWifiPassword() async {
    final value = _wifiPasswordCtrl.text.trim();
    await ref.read(deviceConfigProvider.notifier).setWifiPassword(value);
    _clearDirty(DeviceConfigField.wifiPassword);
  }

  Future<void> _submitBattery() async {
    final text = _batteryCtrl.text.trim();
    final wh = int.tryParse(text);
    if (wh == null || wh < 0 || wh > 65535) {
      _showError('Enter a valid battery capacity (0–65535 Wh)');
      return;
    }
    await ref.read(deviceConfigProvider.notifier).setBatteryCapacity(wh);
    _clearDirty(DeviceConfigField.batteryCapacity);
  }

  /// Show a reboot warning dialog, then send the command if confirmed.
  Future<bool> _confirmReboot(String setting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reboot required'),
        content: Text(
          'Changing $setting will reboot the ORD Dash. '
          'The app will reconnect automatically after the reboot. Proceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reboot')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _toggleBle(bool on) async {
    if (!await _confirmReboot('BLE')) return;
    await ref.read(deviceConfigProvider.notifier).setBleEnabled(on);
  }

  Future<void> _toggleSta(bool on) async {
    if (!await _confirmReboot('WiFi STA')) return;
    await ref.read(deviceConfigProvider.notifier).setStaEnabled(on);
  }

  Future<void> _toggleAp(bool on) async {
    if (!await _confirmReboot('WiFi AP')) return;
    await ref.read(deviceConfigProvider.notifier).setApEnabled(on);
  }

  Future<void> _toggleSim(bool on) async {
    await ref.read(deviceConfigProvider.notifier).setSimEnabled(on);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Watch the dash connection state.
    final dashState = ref.watch(dashConnectionStateProvider).value;
    _disconnected = dashState != BleConnectionState.connected;

    // Watch the device config state.
    final state = ref.watch(deviceConfigProvider);
    final config = state.config;
    final inProgress = state.inProgress;
    final errors = state.errors;

    // Sync text controllers with state (when state changes externally).
    ref.listen<DeviceConfigState>(deviceConfigProvider, (_, next) {
      _syncFromState();
    });

    if (_disconnected && !_fetching) {
      // Show a disconnected state.
      return Scaffold(
        appBar: AppBar(title: const Text('Device Settings')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Device disconnected', style: TextStyle(fontSize: 18)),
              SizedBox(height: 8),
              Text('All settings are unavailable while disconnected.'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Settings'),
        actions: [
          if (_fetching)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: _fetching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Hostname --
                  _buildTextField(
                    label: 'Hostname',
                    controller: _hostnameCtrl,
                    focusNode: _hostnameFocus,
                    inProgress: inProgress.contains(DeviceConfigField.hostname),
                    error: errors[DeviceConfigField.hostname],
                    isDirty: _dirty[DeviceConfigField.hostname] == true,
                    onSubmit: _submitHostname,
                    unknown: config.hostname == null,
                  ),
                  const SizedBox(height: 16),

                  // -- WiFi STA SSID --
                  _buildTextField(
                    label: 'WiFi STA SSID',
                    controller: _wifiSsidCtrl,
                    focusNode: _wifiSsidFocus,
                    inProgress: inProgress.contains(DeviceConfigField.wifiSsid),
                    error: errors[DeviceConfigField.wifiSsid],
                    isDirty: _dirty[DeviceConfigField.wifiSsid] == true,
                    onSubmit: _submitWifiSsid,
                    unknown: config.wifiSsid == null,
                  ),
                  const SizedBox(height: 16),

                  // -- WiFi STA Password --
                  _buildTextField(
                    label: 'WiFi STA Password',
                    controller: _wifiPasswordCtrl,
                    focusNode: _wifiPasswordFocus,
                    inProgress: inProgress.contains(DeviceConfigField.wifiPassword),
                    error: errors[DeviceConfigField.wifiPassword],
                    isDirty: _dirty[DeviceConfigField.wifiPassword] == true,
                    onSubmit: _submitWifiPassword,
                    obscureText: true,
                    unknown: config.wifiPassword == null,
                  ),
                  const SizedBox(height: 16),

                  // -- Battery capacity --
                  _buildTextField(
                    label: 'Battery Capacity (Wh)',
                    controller: _batteryCtrl,
                    focusNode: _batteryFocus,
                    inProgress: inProgress.contains(DeviceConfigField.batteryCapacity),
                    error: errors[DeviceConfigField.batteryCapacity],
                    isDirty: _dirty[DeviceConfigField.batteryCapacity] == true,
                    onSubmit: _submitBattery,
                    keyboardType: TextInputType.number,
                    unknown: config.batteryCapacityWh == null,
                  ),
                  const SizedBox(height: 24),

                  // -- Toggles --
                  Text('Toggles', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),

                  _buildSwitchTile(
                    label: 'BLE',
                    subtitle: 'Reboots the device on change',
                    value: config.bleEnabled ?? false,
                    unknown: config.bleEnabled == null,
                    inProgress: inProgress.contains(DeviceConfigField.bleEnabled),
                    error: errors[DeviceConfigField.bleEnabled],
                    onChanged: (on) => _toggleBle(on),
                  ),
                  _buildSwitchTile(
                    label: 'WiFi STA',
                    subtitle: 'Reboots the device on change',
                    value: config.staEnabled ?? false,
                    unknown: config.staEnabled == null,
                    inProgress: inProgress.contains(DeviceConfigField.staEnabled),
                    error: errors[DeviceConfigField.staEnabled],
                    onChanged: (on) => _toggleSta(on),
                  ),
                  _buildSwitchTile(
                    label: 'WiFi AP',
                    subtitle: 'Reboots the device on change',
                    value: config.apEnabled ?? false,
                    unknown: config.apEnabled == null,
                    inProgress: inProgress.contains(DeviceConfigField.apEnabled),
                    error: errors[DeviceConfigField.apEnabled],
                    onChanged: (on) => _toggleAp(on),
                  ),
                  if (config.simAvailable)
                    _buildSwitchTile(
                      label: 'Simulator',
                      subtitle: 'Simulates e-bike activity',
                      value: config.simEnabled ?? false,
                      unknown: config.simEnabled == null,
                      inProgress: inProgress.contains(DeviceConfigField.simEnabled),
                      error: errors[DeviceConfigField.simEnabled],
                      onChanged: (on) => _toggleSim(on),
                    ),

                  const SizedBox(height: 32),

                  // -- Disconnected banner --
                  if (_disconnected)
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.link_off, color: theme.colorScheme.onErrorContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Device disconnected. Settings are unavailable.', style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget builders
  // ---------------------------------------------------------------------------

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool inProgress,
    String? error,
    required bool isDirty,
    required VoidCallback onSubmit,
    bool obscureText = false,
    TextInputType? keyboardType,
    bool unknown = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscureText,
                keyboardType: keyboardType,
                enabled: !inProgress && !_disconnected && !unknown,
                decoration: InputDecoration(
                  labelText: label,
                  border: isDirty ? const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange, width: 2)) : null,
                  suffixIcon: inProgress ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                  hintText: unknown ? 'Fetching…' : null,
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String label,
    required String subtitle,
    required bool value,
    required bool unknown,
    required bool inProgress,
    String? error,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(label),
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
          value: value,
          onChanged: (!inProgress && !_disconnected && !unknown) ? (v) => onChanged(v) : null,
          secondary: inProgress
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : unknown
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 72, bottom: 4),
            child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}
