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
    String downloadUrl, // Now expects the actual download URL
    String fileName,
    {Function(int downloaded, int total)? onProgress}
  ) async {
    try {
      // Get download directory
      final downloadDir = await _getDownloadDirectory();
      final filePath = path.join(downloadDir, fileName);

      // Create cancel token for this download
      final cancelToken = CancelToken();
      _downloadCancelTokens[downloadUrl] = cancelToken;

      print('Starting download: $downloadUrl');
      print('Saving to: $filePath');

      // Use the JustFlightService's Dio instance to maintain session/cookies
      final justFlightDio = _justFlightService.getDioInstance();
      
      // Download the file using the authenticated session
      await justFlightDio.download(
        downloadUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (downloaded, total) {
          if (onProgress != null && total != -1) {
            onProgress(downloaded, total);
          }
          print('Download progress: ${downloaded}/${total} bytes');
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 30),
          validateStatus: (status) => status! < 400,
        ),
      );

      print('Download completed: $filePath');

      // Remove cancel token
      _downloadCancelTokens.remove(downloadUrl);

      return filePath;
    } on DioException catch (e) {
      _downloadCancelTokens.remove(downloadUrl);
      
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
      _downloadCancelTokens.remove(downloadUrl);
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

  void cancelDownload(String downloadUrl) {
    final cancelToken = _downloadCancelTokens[downloadUrl];
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
