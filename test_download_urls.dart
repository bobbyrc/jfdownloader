import 'package:jfdownloader/services/justflight_service.dart';
import 'dart:io';

void main() async {
  print('Testing download URL access...');
  
  final service = JustFlightService();
  
  try {
    // Test the download URLs directly
    final testUrls = [
      'https://www.justflight.com/productdownloads/a86baf5a-117b-4c9c-9c74-f57388ccc356',
      'https://www.justflight.com/productdownloads/3d95d8cb-421c-49d6-a3cd-32ea40031050',
    ];
    
    for (final url in testUrls) {
      print('\n--- Testing URL: $url ---');
      
      try {
        final dio = service.getDioInstance();
        final response = await dio.head(url);
        
        print('Status: ${response.statusCode}');
        print('Headers:');
        response.headers.forEach((key, values) {
          print('  $key: ${values.join(', ')}');
        });
        
        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          final sizeInMB = int.parse(contentLength) / (1024 * 1024);
          print('File size: ${sizeInMB.toStringAsFixed(2)} MB');
        }
        
      } catch (e) {
        print('ERROR: $e');
      }
    }
    
  } catch (e) {
    print('Service error: $e');
  }
  
  exit(0);
}
