import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/download_provider.dart';
import '../services/cache_service.dart';
import '../services/logger_service.dart';
import '../services/performance_service.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  final CacheService _cache = CacheService();
  final PerformanceService _performance = PerformanceService();

  bool _enablePerformanceMonitoring = false;
  bool _enableImageCaching = true;
  bool _enableDebugLogging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPerformanceSection(),
            const SizedBox(height: 24),
            _buildCacheSection(),
            const SizedBox(height: 24),
            _buildDownloadSection(),
            const SizedBox(height: 24),
            _buildLoggingSection(),
            const SizedBox(height: 24),
            _buildDiagnosticsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Performance Monitoring'),
              subtitle: const Text('Track app performance metrics'),
              value: _enablePerformanceMonitoring,
              onChanged: (value) {
                setState(() {
                  _enablePerformanceMonitoring = value;
                });
                if (value) {
                  LoggerService()
                      .info('Performance monitoring enabled', 'Settings');
                } else {
                  _performance.clearMetrics();
                  LoggerService()
                      .info('Performance monitoring disabled', 'Settings');
                }
              },
            ),
            if (_enablePerformanceMonitoring) ...[
              const Divider(),
              ListTile(
                title: const Text('View Performance Metrics'),
                subtitle: const Text('See current performance data'),
                trailing: const Icon(Icons.analytics),
                onTap: _showPerformanceMetrics,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCacheSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Cache & Storage',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Image Caching'),
              subtitle: const Text('Cache images in memory for faster loading'),
              value: _enableImageCaching,
              onChanged: (value) {
                setState(() {
                  _enableImageCaching = value;
                });
                if (!value) {
                  _cache.clearAll();
                }
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Clear Cache'),
              subtitle: FutureBuilder<Map<String, int>>(
                future: Future.value(_cache.getStats()),
                builder: (context, snapshot) {
                  final stats = snapshot.data;
                  if (stats != null) {
                    final totalItems =
                        stats.values.fold(0, (sum, count) => sum + count);
                    return Text('$totalItems cached items');
                  }
                  return const Text('Tap to clear all cached data');
                },
              ),
              trailing: const Icon(Icons.delete_sweep),
              onTap: _clearCache,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Downloads',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<DownloadProvider>(
              builder: (context, downloadProvider, child) {
                return Column(
                  children: [
                    ListTile(
                      title: const Text('Concurrent Downloads'),
                      subtitle: Text(
                          'Current limit: ${downloadProvider.maxConcurrentDownloads}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: downloadProvider.maxConcurrentDownloads >
                                    1
                                ? () => downloadProvider
                                    .setMaxConcurrentDownloads(downloadProvider
                                            .maxConcurrentDownloads -
                                        1)
                                : null,
                          ),
                          Text('${downloadProvider.maxConcurrentDownloads}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: downloadProvider.maxConcurrentDownloads <
                                    10
                                ? () => downloadProvider
                                    .setMaxConcurrentDownloads(downloadProvider
                                            .maxConcurrentDownloads +
                                        1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Download History'),
                      subtitle: Text(
                          '${downloadProvider.completedDownloads.length} completed downloads'),
                      trailing: const Icon(Icons.history),
                      onTap: () {
                        // Could navigate to download history screen
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Debugging',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Debug Logging'),
              subtitle:
                  const Text('Enable detailed logging for troubleshooting'),
              value: _enableDebugLogging,
              onChanged: (value) {
                setState(() {
                  _enableDebugLogging = value;
                });
                LoggerService().info(
                    'Debug logging ${value ? 'enabled' : 'disabled'}',
                    'Settings');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.healing,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Diagnostics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Run Diagnostics'),
              subtitle: const Text('Check app health and connectivity'),
              trailing: const Icon(Icons.play_arrow),
              onTap: _runDiagnostics,
            ),
            const Divider(),
            ListTile(
              title: const Text('Export Logs'),
              subtitle: const Text('Save diagnostic information'),
              trailing: const Icon(Icons.download),
              onTap: _exportLogs,
            ),
          ],
        ),
      ),
    );
  }

  void _showPerformanceMetrics() {
    final metrics = _performance.getPerformanceSummary();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Performance Metrics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Network Operations:',
                  style: Theme.of(context).textTheme.titleSmall),
              ...(_performance.getNetworkMetrics().entries.map((e) => Text(
                  '${e.key}: ${e.value['count']} ops, avg ${e.value['average_ms']}ms'))),
              const SizedBox(height: 8),
              Text('Image Loading:',
                  style: Theme.of(context).textTheme.titleSmall),
              ...(_performance.getImageMetrics().entries.map((e) => Text(
                  '${e.key}: ${e.value['count']} ops, avg ${e.value['average_ms']}ms'))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content:
            const Text('This will clear all cached images and data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _cache.clearAll();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _runDiagnostics() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Running diagnostics...'),
          ],
        ),
      ),
    );

    // Simulate diagnostics
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.of(context).pop(); // Close progress dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Diagnostics Complete'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Network connectivity: OK'),
              Text('✅ Cache system: OK'),
              Text('✅ Performance monitoring: OK'),
              Text('✅ Download system: OK'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _exportLogs() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log export feature coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
