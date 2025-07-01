#!/usr/bin/env dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

void main() async {
  print('=== JustFlight Downloader Performance Benchmark ===\n');

  // Run various performance tests
  await runMemoryBenchmark();
  await runIOBenchmark();
  await runComputeBenchmark();
  await runStringProcessingBenchmark();

  print('\n=== Benchmark Complete ===');
}

Future<void> runMemoryBenchmark() async {
  print('📊 Memory Allocation Benchmark');
  final stopwatch = Stopwatch()..start();

  // Simulate memory-intensive operations
  final lists = <List<int>>[];
  for (int i = 0; i < 1000; i++) {
    lists.add(List.generate(1000, (index) => index));
  }

  stopwatch.stop();
  print('   Memory allocation test: ${stopwatch.elapsedMilliseconds}ms');

  // Clean up
  lists.clear();
}

Future<void> runIOBenchmark() async {
  print('📁 File I/O Benchmark');
  final tempDir = Directory.systemTemp.createTempSync('jf_benchmark');
  final testFile = File('${tempDir.path}/test.txt');

  // Write test
  final stopwatchWrite = Stopwatch()..start();
  final largeString = 'A' * 100000; // 100KB string
  await testFile.writeAsString(largeString);
  stopwatchWrite.stop();
  print('   File write (100KB): ${stopwatchWrite.elapsedMilliseconds}ms');

  // Read test
  final stopwatchRead = Stopwatch()..start();
  final content = await testFile.readAsString();
  stopwatchRead.stop();
  print('   File read (100KB): ${stopwatchRead.elapsedMilliseconds}ms');

  // Clean up
  tempDir.deleteSync(recursive: true);
}

Future<void> runComputeBenchmark() async {
  print('🔢 Computation Benchmark');
  
  // CPU-intensive calculation
  final stopwatch = Stopwatch()..start();
  int result = 0;
  for (int i = 0; i < 1000000; i++) {
    result += (i * i) % 1000;
  }
  stopwatch.stop();
  print('   Mathematical computation: ${stopwatch.elapsedMilliseconds}ms (result: $result)');

  // List operations
  final listStopwatch = Stopwatch()..start();
  final numbers = List.generate(100000, (index) => Random().nextInt(1000));
  numbers.sort();
  final sum = numbers.reduce((a, b) => a + b);
  listStopwatch.stop();
  print('   List operations (100k items): ${listStopwatch.elapsedMilliseconds}ms (sum: $sum)');
}

Future<void> runStringProcessingBenchmark() async {
  print('📋 String Processing Benchmark');
  
  // Simulate JSON-like string parsing
  final stopwatch = Stopwatch()..start();
  
  final mockJsonString = '''
  {
    "products": [
      {"id": 1, "name": "Aircraft A", "category": "Aircraft", "size": 250.5},
      {"id": 2, "name": "Aircraft B", "category": "Aircraft", "size": 180.2},
      {"id": 3, "name": "Scenery Pack", "category": "Scenery", "size": 1200.8}
    ]
  }
  ''';
  
  // Parse manually (simplified)
  int parseCount = 0;
  for (int i = 0; i < 10000; i++) {
    if (mockJsonString.contains('Aircraft')) parseCount++;
    if (mockJsonString.contains('Scenery')) parseCount++;
  }
  
  stopwatch.stop();
  print('   String processing (10k iterations): ${stopwatch.elapsedMilliseconds}ms (matches: $parseCount)');
}
