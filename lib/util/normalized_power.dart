import 'dart:math' as math;
import 'dart:collection';

/// Computes Normalized Power (NP) using the standard 30-second rolling
/// average algorithm (Coggan / TrainingPeaks).
///
/// Labeled as "WAP" (Weighted Average Power) in the UI to avoid trademark
/// issues with "Normalized Power" (TrainingPeaks).
///
/// Usage (batch):
/// ```dart
/// final np = NormalizedPowerCalculator();
/// for (final s in samples) {
///   if (s.speedKmh > 2.0) np.addSample(s.humanPowerW);
/// }
/// final result = np.normalizedPower;
/// ```
///
/// Usage (live):
/// ```dart
/// final np = NormalizedPowerCalculator();
/// // on each telemetry tick:
/// np.addSample(t.humanPowerW);
/// final live = np.normalizedPower;
/// ```
class NormalizedPowerCalculator {
  /// Rolling window size in samples (~1 Hz → 30 seconds).
  static const int windowSize = 30;

  final Queue<double> _window = Queue();
  double _windowSum = 0;
  double _total4 = 0;
  int _completedWindows = 0;

  /// Whether at least one full window has been accumulated.
  bool get hasResult => _completedWindows > 0;

  /// The current Normalized Power value, or null if fewer than
  /// [windowSize] samples have been added.
  double? get normalizedPower {
    if (_completedWindows == 0) return null;
    return math.sqrt(math.sqrt(_total4 / _completedWindows));
  }

  /// Add a single power sample to the rolling window.
  void addSample(double power) {
    _window.addLast(power);
    _windowSum += power;
    if (_window.length > windowSize) {
      _windowSum -= _window.removeFirst();
    }
    if (_window.length == windowSize) {
      final avg30 = _windowSum / windowSize;
      _total4 += avg30 * avg30 * avg30 * avg30;
      _completedWindows++;
    }
  }

  /// Reset all internal state (e.g. when starting a new ride).
  void reset() {
    _window.clear();
    _windowSum = 0;
    _total4 = 0;
    _completedWindows = 0;
  }
}
