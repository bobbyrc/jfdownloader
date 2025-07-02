import 'package:flutter/foundation.dart';
import '../models/download_progress.dart';
import '../models/product.dart';
import '../services/download_service.dart';
import '../services/logger_service.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();
  final _logger = LoggerService();

  final Map<String, DownloadProgress> _downloads = {};
  final Map<String, ProductFile> _downloadFiles =
      {}; // Store ProductFile objects
  final List<String> _downloadQueue = [];
  bool _isDownloading = false;
  int _maxConcurrentDownloads = 3;

  Map<String, DownloadProgress> get downloads => Map.unmodifiable(_downloads);
  List<String> get downloadQueue => List.unmodifiable(_downloadQueue);
  bool get isDownloading => _isDownloading;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  List<DownloadProgress> get activeDownloads => _downloads.values
      .where((d) => d.status == DownloadStatus.downloading)
      .toList();

  List<DownloadProgress> get completedDownloads => _downloads.values
      .where((d) => d.status == DownloadStatus.completed)
      .toList();

  List<DownloadProgress> get failedDownloads => _downloads.values
      .where((d) => d.status == DownloadStatus.failed)
      .toList();

  double get totalProgress {
    if (_downloads.isEmpty) return 0.0;

    final total =
        _downloads.values.fold<double>(0.0, (sum, d) => sum + d.progress);
    return total / _downloads.length;
  }

  Future<void> downloadProduct(Product product, String downloadPath) async {
    for (final file in product.files) {
      await downloadFile(file, downloadPath);
    }
  }

  Future<void> downloadFile(ProductFile file, String downloadPath) async {
    if (_downloads.containsKey(file.id)) {
      // Already downloading or downloaded
      return;
    }

    // Store the ProductFile for later use
    _downloadFiles[file.id] = file;

    final progress = DownloadProgress(
      fileId: file.id,
      fileName: file.name,
      totalBytes: file.sizeInMB * 1024 * 1024,
      downloadedBytes: 0,
      progress: 0,
      status: DownloadStatus.pending,
      startTime: DateTime.now(),
    );

    _downloads[file.id] = progress;
    _downloadQueue.add(file.id);
    notifyListeners();

    _processDownloadQueue();
  }

  Future<void> _processDownloadQueue() async {
    // Don't process if queue is empty
    if (_downloadQueue.isEmpty) {
      // Check if all downloads are complete
      if (activeDownloads.isEmpty) {
        _isDownloading = false;
      }
      notifyListeners();
      return;
    }

    _isDownloading = true;

    while (_downloadQueue.isNotEmpty &&
        activeDownloads.length < _maxConcurrentDownloads) {
      final fileId = _downloadQueue.removeAt(0);
      final progress = _downloads[fileId];

      if (progress != null && progress.status == DownloadStatus.pending) {
        _startDownload(fileId);
      }
    }

    // Check if all downloads are complete
    if (activeDownloads.isEmpty && _downloadQueue.isEmpty) {
      _isDownloading = false;
    }

    notifyListeners();
  }

  String _formatErrorMessage(Object error) {
    final errorStr = error.toString();

    // Remove "Exception:" prefix if present
    String cleanError = errorStr;
    if (cleanError.startsWith('Exception: ')) {
      cleanError = cleanError.substring(11);
    }

    // Map technical errors to user-friendly messages
    if (cleanError.toLowerCase().contains('cancelled')) {
      return 'Download cancelled';
    } else if (cleanError.toLowerCase().contains('timeout')) {
      return 'Download timed out';
    } else if (cleanError.toLowerCase().contains('connection')) {
      return 'Connection failed';
    } else if (cleanError.toLowerCase().contains('network')) {
      return 'Network error';
    } else if (cleanError.toLowerCase().contains('file not found')) {
      return 'File not found on server';
    } else if (cleanError.toLowerCase().contains('unauthorized')) {
      return 'Authentication required';
    } else if (cleanError.toLowerCase().contains('forbidden')) {
      return 'Access denied';
    } else {
      return cleanError;
    }
  }

  Future<void> _startDownload(String fileId) async {
    final progress = _downloads[fileId];
    final file = _downloadFiles[fileId];

    if (progress == null || file == null) {
      return;
    }

    try {
      _downloads[fileId] =
          progress.copyWith(status: DownloadStatus.downloading);
      notifyListeners();

      // Use the actual download URL from the ProductFile
      await _downloadService.downloadFile(
        file.downloadUrl, // Pass the download URL instead of file ID
        progress.fileName,
        onProgress: (downloaded, total) {
          final updatedProgress = _downloads[fileId]?.copyWith(
            downloadedBytes: downloaded.toDouble(),
            totalBytes: total.toDouble(),
            progress: downloaded / total,
          );

          if (updatedProgress != null) {
            _downloads[fileId] = updatedProgress;
            notifyListeners();
          }
        },
      );

      _downloads[fileId] = progress.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        endTime: DateTime.now(),
        clearError: true,
      );
    } catch (e) {
      _downloads[fileId] = progress.copyWith(
        status: DownloadStatus.failed,
        error: _formatErrorMessage(e),
        endTime: DateTime.now(),
      );
    }

    notifyListeners();
    _processDownloadQueue();
  }

  void pauseDownload(String fileId) {
    final progress = _downloads[fileId];
    if (progress != null && progress.status == DownloadStatus.downloading) {
      _downloads[fileId] = progress.copyWith(status: DownloadStatus.paused);
      notifyListeners();
    }
  }

  void resumeDownload(String fileId) {
    final progress = _downloads[fileId];
    if (progress != null && progress.status == DownloadStatus.paused) {
      _downloads[fileId] = progress.copyWith(status: DownloadStatus.pending);
      if (!_downloadQueue.contains(fileId)) {
        _downloadQueue.add(fileId);
      }
      notifyListeners();
      _processDownloadQueue();
    }
  }

  void cancelDownload(String fileId) {
    _logger.debug('Cancel download requested for fileId: $fileId');
    final progress = _downloads[fileId];
    final file = _downloadFiles[fileId];

    _logger.debug(
        'Found progress: ${progress != null}, status: ${progress?.status}');
    _logger.debug('Found file: ${file != null}');

    if (progress != null) {
      // Cancel the actual download operation if it's in progress
      if (file != null && progress.status == DownloadStatus.downloading) {
        _logger.debug('Cancelling active download via service');
        _downloadService.cancelDownload(file.downloadUrl);
      }

      _downloads[fileId] = progress.copyWith(
        status: DownloadStatus.cancelled,
        error: 'Download cancelled',
        endTime: DateTime.now(),
      );
      _downloadQueue.remove(fileId);
      _logger.debug('Set status to cancelled, removed from queue');
      notifyListeners();
    } else {
      _logger.debug('No progress found for fileId: $fileId');
    }
  }

  void retryDownload(String fileId) {
    _logger.debug('Retry download requested for fileId: $fileId');
    final progress = _downloads[fileId];
    _logger.debug(
        'Current progress status: ${progress?.status}, error: ${progress?.error}');

    if (progress != null &&
        (progress.status == DownloadStatus.failed ||
            progress.status == DownloadStatus.cancelled)) {
      _downloads[fileId] = progress.copyWith(
        status: DownloadStatus.pending,
        downloadedBytes: 0,
        progress: 0,
        startTime: DateTime.now(),
        clearError: true,
      );

      _logger.debug('Updated progress to pending, error cleared');

      if (!_downloadQueue.contains(fileId)) {
        _downloadQueue.add(fileId);
      }

      notifyListeners();
      _processDownloadQueue();
    } else {
      _logger.debug('Cannot retry - status: ${progress?.status}');
    }
  }

  void clearCompletedDownloads() {
    _downloads
        .removeWhere((key, value) => value.status == DownloadStatus.completed);
    notifyListeners();
  }

  void setMaxConcurrentDownloads(int max) {
    _maxConcurrentDownloads = max.clamp(1, 10);
    notifyListeners();
  }

  DownloadProgress? getDownloadProgress(String fileId) {
    return _downloads[fileId];
  }
}
