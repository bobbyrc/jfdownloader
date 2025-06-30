import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'justflight_service.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final JustFlightService _justFlightService = JustFlightService();
  final Map<String, CancelToken> _downloadCancelTokens = {};

  Future<String> downloadFile(
    String fileId,
    String fileName,
    {Function(int downloaded, int total)? onProgress}
  ) async {
    try {
      // Get download directory
      final downloadDir = await _getDownloadDirectory();
      final filePath = path.join(downloadDir, fileName);

      // Create cancel token for this download
      final cancelToken = CancelToken();
      _downloadCancelTokens[fileId] = cancelToken;

      // Get the actual download URL
      final downloadUrl = await _justFlightService.getDownloadUrl(fileId);

      // Download the file
      await _dio.download(
        downloadUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (downloaded, total) {
          if (onProgress != null && total != -1) {
            onProgress(downloaded, total);
          }
        },
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
          },
          receiveTimeout: const Duration(minutes: 30),
        ),
      );

      // Remove cancel token
      _downloadCancelTokens.remove(fileId);

      return filePath;
    } on DioException catch (e) {
      _downloadCancelTokens.remove(fileId);
      
      if (e.type == DioExceptionType.cancel) {
        throw Exception('Download cancelled');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Download timeout');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout');
      } else {
        throw Exception('Download failed: ${e.message}');
      }
    } catch (e) {
      _downloadCancelTokens.remove(fileId);
      throw Exception('Download failed: $e');
    }
  }

  Future<String> _getDownloadDirectory() async {
    Directory? downloadDir;
    
    if (Platform.isMacOS) {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        downloadDir = Directory(path.join(homeDir, 'Downloads', 'JustFlight'));
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        downloadDir = Directory(path.join(userProfile, 'Downloads', 'JustFlight'));
      }
    } else if (Platform.isLinux) {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        downloadDir = Directory(path.join(homeDir, 'Downloads', 'JustFlight'));
      }
    }
    
    // Fallback to documents directory
    downloadDir ??= Directory(path.join((await getApplicationDocumentsDirectory()).path, 'Downloads'));
    
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }
    
    return downloadDir.path;
  }

  void cancelDownload(String fileId) {
    final cancelToken = _downloadCancelTokens[fileId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('User cancelled download');
    }
  }

  Future<int> getFileSize(String url) async {
    try {
      final response = await _dio.head(url);
      final contentLength = response.headers.value('content-length');
      return contentLength != null ? int.parse(contentLength) : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> isFileDownloaded(String fileName) async {
    try {
      final downloadDir = await _getDownloadDirectory();
      final filePath = path.join(downloadDir, fileName);
      return File(filePath).existsSync();
    } catch (e) {
      return false;
    }
  }

  Future<String?> getLocalFilePath(String fileName) async {
    try {
      final downloadDir = await _getDownloadDirectory();
      final filePath = path.join(downloadDir, fileName);
      return File(filePath).existsSync() ? filePath : null;
    } catch (e) {
      return null;
    }
  }
}
