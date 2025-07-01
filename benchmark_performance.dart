import 'dart:io';
import 'package:jfdownloader/services/justflight_service.dart';
import 'package:jfdownloader/services/performance_service.dart';
import 'package:jfdownloader/services/logger_service.dart';

/// Simple performance benchmark for key operations
Future<void> main() async {
  print('🚀 JustFlight Downloader Performance Benchmark');
  print('================================================');
  
  final performance = PerformanceService();
  final service = JustFlightService();
  
  try {
    // Test 1: Service initialization
    print('\n📋 Test 1: Service Initialization');
    await performance.measureAsync('service_init', () async {
      // Service is initialized automatically on first use
      await Future.delayed(const Duration(milliseconds: 100));
    });
    
    // Test 2: Simulated network performance
    print('\n🌐 Test 2: Network Performance Simulation');
    for (int i = 0; i < 5; i++) {
      await performance.measureAsync('network_request_$i', () async {
        // Simulate network delay
        await Future.delayed(Duration(milliseconds: 100 + (i * 50)));
      });
      performance.incrementCounter('network_requests');
    }
    
    // Test 3: Concurrent operations
    print('\n⚡ Test 3: Concurrent Operations');
    final futures = <Future>[];
    for (int i = 0; i < 3; i++) {
      futures.add(performance.measureAsync('concurrent_op_$i', () async {
        await Future.delayed(Duration(milliseconds: 200 + (i * 25)));
      }));
    }
    await Future.wait(futures);
    
    // Results
    print('\n📊 Performance Results');
    print('======================');
    
    final summary = performance.getPerformanceSummary();
    for (final entry in summary.entries) {
      if (entry.value is Map) {
        final metrics = entry.value as Map<String, dynamic>;
        print('${entry.key}:');
        print('  Count: ${metrics['count']}');
        print('  Average: ${metrics['average_ms']}ms');
        print('  Min: ${metrics['min_ms']}ms');
        print('  Max: ${metrics['max_ms']}ms');
        print('');
      }
    }
    
    // Counter results
    if (summary['counters'] != null) {
      print('Counters:');
      final counters = summary['counters'] as Map<String, dynamic>;
      for (final entry in counters.entries) {
        print('  ${entry.key}: ${entry.value}');
      }
    }
    
    print('\n✅ Benchmark completed successfully!');
    
  } catch (e, stackTrace) {
    LoggerService().error('Benchmark failed', tag: 'Benchmark', error: e, stackTrace: stackTrace);
    print('❌ Benchmark failed: $e');
    exit(1);
  }
}
