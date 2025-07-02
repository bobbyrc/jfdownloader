import 'dart:async';
import '../services/logger_service.dart';

/// Performance monitoring and metrics collection service
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  /// Initialize the performance service
  static Future<void> initialize() async {
    // Performance service initializes on first access
    PerformanceService(); // Create instance to trigger initialization
  }

  final _timers = <String, Stopwatch>{};
  final _metrics = <String, List<Duration>>{};
  final _counters = <String, int>{};
  final LoggerService _logger = LoggerService();

  /// Start a performance timer
  void startTimer(String name) {
    final stopwatch = Stopwatch()..start();
    _timers[name] = stopwatch;
    _logger.debug('Started timer: $name', 'Performance');
  }

  /// Stop a performance timer and record the duration
  Duration? stopTimer(String name) {
    final stopwatch = _timers.remove(name);
    if (stopwatch != null) {
      stopwatch.stop();
      final duration = stopwatch.elapsed;

      // Store metric
      _metrics.putIfAbsent(name, () => <Duration>[]).add(duration);

      LoggerService().debug(
          'Stopped timer: $name (${duration.inMilliseconds}ms)', 'Performance');
      return duration;
    }
    return null;
  }

  /// Measure the performance of an async operation
  Future<T> measureAsync<T>(String name, Future<T> Function() operation) async {
    startTimer(name);
    try {
      final result = await operation();
      return result;
    } finally {
      stopTimer(name);
    }
  }

  /// Measure the performance of a sync operation
  T measure<T>(String name, T Function() operation) {
    startTimer(name);
    try {
      return operation();
    } finally {
      stopTimer(name);
    }
  }

  /// Increment a counter metric
  void incrementCounter(String name, [int amount = 1]) {
    _counters[name] = (_counters[name] ?? 0) + amount;
  }

  /// Get average duration for a metric
  Duration? getAverageDuration(String name) {
    final durations = _metrics[name];
    if (durations == null || durations.isEmpty) return null;

    final totalMs = durations.fold(0, (sum, d) => sum + d.inMilliseconds);
    return Duration(milliseconds: (totalMs / durations.length).round());
  }

  /// Get total duration for a metric
  Duration? getTotalDuration(String name) {
    final durations = _metrics[name];
    if (durations == null || durations.isEmpty) return null;

    final totalMs = durations.fold(0, (sum, d) => sum + d.inMilliseconds);
    return Duration(milliseconds: totalMs);
  }

  /// Get the count of measurements for a metric
  int getMeasurementCount(String name) {
    return _metrics[name]?.length ?? 0;
  }

  /// Get counter value
  int getCounter(String name) {
    return _counters[name] ?? 0;
  }

  /// Get performance summary
  Map<String, dynamic> getPerformanceSummary() {
    final summary = <String, dynamic>{};

    // Add timing metrics
    for (final entry in _metrics.entries) {
      final name = entry.key;
      final durations = entry.value;

      if (durations.isNotEmpty) {
        final avg = getAverageDuration(name);
        final total = getTotalDuration(name);

        summary[name] = {
          'count': durations.length,
          'average_ms': avg?.inMilliseconds ?? 0,
          'total_ms': total?.inMilliseconds ?? 0,
          'min_ms': durations
              .map((d) => d.inMilliseconds)
              .reduce((a, b) => a < b ? a : b),
          'max_ms': durations
              .map((d) => d.inMilliseconds)
              .reduce((a, b) => a > b ? a : b),
        };
      }
    }

    // Add counters
    if (_counters.isNotEmpty) {
      summary['counters'] = Map.from(_counters);
    }

    return summary;
  }

  /// Clear all metrics
  void clearMetrics() {
    _timers.clear();
    _metrics.clear();
    _counters.clear();
    _logger.info('Performance metrics cleared', 'Performance');
  }

  /// Log performance summary
  void logSummary() {
    final summary = getPerformanceSummary();
    _logger.info('Performance Summary: $summary', 'Performance');
  }

  /// Get metrics for specific operation types
  Map<String, dynamic> getNetworkMetrics() {
    final networkMetrics = <String, dynamic>{};
    for (final entry in _metrics.entries) {
      if (entry.key.contains('network') ||
          entry.key.contains('http') ||
          entry.key.contains('download')) {
        final avg = getAverageDuration(entry.key);
        networkMetrics[entry.key] = {
          'count': entry.value.length,
          'average_ms': avg?.inMilliseconds ?? 0,
        };
      }
    }
    return networkMetrics;
  }

  /// Get image loading metrics
  Map<String, dynamic> getImageMetrics() {
    final imageMetrics = <String, dynamic>{};
    for (final entry in _metrics.entries) {
      if (entry.key.contains('image') || entry.key.contains('fetch')) {
        final avg = getAverageDuration(entry.key);
        imageMetrics[entry.key] = {
          'count': entry.value.length,
          'average_ms': avg?.inMilliseconds ?? 0,
        };
      }
    }
    return imageMetrics;
  }
}
