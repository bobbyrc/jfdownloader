import 'package:flutter/foundation.dart';
import '../models/download_progress.dart';
import '../models/product.dart';
import '../services/download_service.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();
  
  final Map<String, DownloadProgress> _downloads = {};
  final List<String> _downloadQueue = [];
  bool _isDownloading = false;
  int _maxConcurrentDownloads = 3;

  Map<String, DownloadProgress> get downloads => Map.unmodifiable(_downloads);
  List<String> get downloadQueue => List.unmodifiable(_downloadQueue);
  bool get isDownloading => _isDownloading;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  
  List<DownloadProgress> get activeDownloads => 
    _downloads.values.where((d) => d.status == DownloadStatus.downloading).toList();
    
  List<DownloadProgress> get completedDownloads => 
    _downloads.values.where((d) => d.status == DownloadStatus.completed).toList();
    
  List<DownloadProgress> get failedDownloads => 
    _downloads.values.where((d) => d.status == DownloadStatus.failed).toList();

  double get totalProgress {
    if (_downloads.isEmpty) return 0.0;
    
    final total = _downloads.values.fold<double>(0.0, (sum, d) => sum + d.progress);
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
    if (_isDownloading || _downloadQueue.isEmpty) return;
    
    _isDownloading = true;
    
    while (_downloadQueue.isNotEmpty && activeDownloads.length < _maxConcurrentDownloads) {
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

  Future<void> _startDownload(String fileId) async {
    final progress = _downloads[fileId];
    if (progress == null) return;

    try {
      _downloads[fileId] = progress.copyWith(status: DownloadStatus.downloading);
      notifyListeners();

      await _downloadService.downloadFile(
        fileId,
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
      );
    } catch (e) {
      _downloads[fileId] = progress.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
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
    final progress = _downloads[fileId];
    if (progress != null) {
      _downloads[fileId] = progress.copyWith(
        status: DownloadStatus.cancelled,
        endTime: DateTime.now(),
      );
      _downloadQueue.remove(fileId);
      notifyListeners();
    }
  }

  void retryDownload(String fileId) {
    final progress = _downloads[fileId];
    if (progress != null && progress.status == DownloadStatus.failed) {
      _downloads[fileId] = progress.copyWith(
        status: DownloadStatus.pending,
        error: null,
        downloadedBytes: 0,
        progress: 0,
        startTime: DateTime.now(),
        endTime: null,
      );
      
      if (!_downloadQueue.contains(fileId)) {
        _downloadQueue.add(fileId);
      }
      
      notifyListeners();
      _processDownloadQueue();
    }
  }

  void clearCompletedDownloads() {
    _downloads.removeWhere((key, value) => value.status == DownloadStatus.completed);
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
