// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DownloadProgress _$DownloadProgressFromJson(Map<String, dynamic> json) =>
    DownloadProgress(
      fileId: json['fileId'] as String,
      fileName: json['fileName'] as String,
      totalBytes: (json['totalBytes'] as num).toDouble(),
      downloadedBytes: (json['downloadedBytes'] as num).toDouble(),
      progress: (json['progress'] as num).toDouble(),
      status: $enumDecode(_$DownloadStatusEnumMap, json['status']),
      error: json['error'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
    );

Map<String, dynamic> _$DownloadProgressToJson(DownloadProgress instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'fileName': instance.fileName,
      'totalBytes': instance.totalBytes,
      'downloadedBytes': instance.downloadedBytes,
      'progress': instance.progress,
      'status': _$DownloadStatusEnumMap[instance.status]!,
      'error': instance.error,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
    };

const _$DownloadStatusEnumMap = {
  DownloadStatus.pending: 'pending',
  DownloadStatus.downloading: 'downloading',
  DownloadStatus.completed: 'completed',
  DownloadStatus.failed: 'failed',
  DownloadStatus.cancelled: 'cancelled',
  DownloadStatus.paused: 'paused',
};
