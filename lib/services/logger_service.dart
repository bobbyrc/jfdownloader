import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Comprehensive logging service for the JustFlight Downloader
/// Provides structured logging with different output strategies for production vs development
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  static bool _initialized = false;
  static bool _isProduction = kReleaseMode;
  
  /// Initialize the logging service
  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    LoggerService().info('Logger service initialized');
  }

  /// Log a debug message (only in debug builds)
  void debug(String message, [String? tag]) {
    if (!kDebugMode) return;
    _log(LogLevel.debug, message, tag: tag);
  }

  /// Log an informational message
  void info(String message, [String? tag]) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Log a warning message
  void warning(String message, [String? tag]) {
    _log(LogLevel.warning, message, tag: tag);
  }

  /// Log an error message with optional error object and stack trace
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void _log(LogLevel level, String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final tagStr = tag != null ? '[$tag] ' : '';
    final formattedMessage = '$timestamp $levelStr $tagStr$message';

    if (_isProduction) {
      // In production, use developer.log for structured logging
      developer.log(
        message,
        time: DateTime.now(),
        level: level.index * 300, // DEBUG: 0, INFO: 300, WARNING: 600, ERROR: 900
        name: tag ?? 'JFDownloader',
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // In development, use print for immediate feedback
      // ignore: avoid_print
      print(formattedMessage);
      if (error != null) {
        // ignore: avoid_print
        print('Error: $error');
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Network request logging with structured data
  void logNetworkRequest(String method, String url, {
    int? statusCode,
    Duration? duration,
    String? error,
  }) {
    final message = '$method $url';
    if (error != null) {
      this.error('$message - Error: $error', tag: 'Network');
    } else if (statusCode != null) {
      final durationMs = duration?.inMilliseconds ?? 0;
      debug('$message - ${statusCode} (${durationMs}ms)', 'Network');
    } else {
      debug(message, 'Network');
    }
  }

  /// Progress logging for long-running operations
  void logProgress(String operation, int completed, int total, [String? details]) {
    final percentage = total > 0 ? (completed / total * 100).toStringAsFixed(1) : '0.0';
    final message = '$operation: $completed/$total ($percentage%)';
    final fullMessage = details != null ? '$message - $details' : message;
    info(fullMessage, 'Progress');
  }
}
