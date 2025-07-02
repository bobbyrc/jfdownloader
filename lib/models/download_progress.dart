import 'package:json_annotation/json_annotation.dart';

part 'download_progress.g.dart';

@JsonSerializable()
class DownloadProgress {
  final String fileId;
  final String fileName;
  final double totalBytes;
  final double downloadedBytes;
  final double progress;
  final DownloadStatus status;
  final String? error;
  final DateTime startTime;
  final DateTime? endTime;

  const DownloadProgress({
    required this.fileId,
    required this.fileName,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.progress,
    required this.status,
    this.error,
    required this.startTime,
    this.endTime,
  });

  factory DownloadProgress.fromJson(Map<String, dynamic> json) =>
      _$DownloadProgressFromJson(json);
  Map<String, dynamic> toJson() => _$DownloadProgressToJson(this);

  DownloadProgress copyWith({
    String? fileId,
    String? fileName,
    double? totalBytes,
    double? downloadedBytes,
    double? progress,
    DownloadStatus? status,
    String? error,
    DateTime? startTime,
    DateTime? endTime,
    bool clearError = false,
  }) {
    return DownloadProgress(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  String get formattedSpeed {
    if (status != DownloadStatus.downloading || endTime != null) return '';

    final duration = DateTime.now().difference(startTime);
    if (duration.inSeconds == 0) return '';

    final bytesPerSecond = downloadedBytes / duration.inSeconds;
    return '${_formatBytes(bytesPerSecond)}/s';
  }

  String get formattedSize {
    return '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}';
  }

  String _formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toInt()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

enum DownloadStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('downloading')
  downloading,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('paused')
  paused,
}
