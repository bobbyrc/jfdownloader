import 'package:jfdownloader/services/justflight_service.dart';
import 'dart:io';

void main() async {
  print('Testing authenticated download URL access...');
  
  final service = JustFlightService();
  
  try {
    // First login
    print('Attempting login...');
    final credentials = await File('credentials.txt').readAsLines();
    if (credentials.length < 2) {
      print('ERROR: credentials.txt needs email and password on separate lines');
      exit(1);
    }
    
    final email = credentials[0].trim();
    final password = credentials[1].trim();
    
    final loginSuccess = await service.login(email, password);
    if (!loginSuccess) {
      print('ERROR: Login failed');
      exit(1);
    }
    
    print('✅ Login successful');
    
    // Test the download URLs with authentication
    final testUrls = [
      'https://www.justflight.com/productdownloads/a86baf5a-117b-4c9c-9c74-f57388ccc356',
      'https://www.justflight.com/productdownloads/3d95d8cb-421c-49d6-a3cd-32ea40031050',
    ];
    
    for (final url in testUrls) {
      print('\n--- Testing URL: $url ---');
      
      try {
        final dio = service.getDioInstance();
        final response = await dio.head(url);
        
        print('✅ Status: ${response.statusCode}');
        
        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          final sizeInMB = int.parse(contentLength) / (1024 * 1024);
          print('📁 File size: ${sizeInMB.toStringAsFixed(2)} MB');
        }
        
        final contentType = response.headers.value('content-type');
        if (contentType != null) {
          print('📄 Content type: $contentType');
        }
        
        final contentDisposition = response.headers.value('content-disposition');
        if (contentDisposition != null) {
          print('📝 Content disposition: $contentDisposition');
        }
        
      } catch (e) {
        print('❌ ERROR: $e');
      }
    }
    
  } catch (e) {
    print('Service error: $e');
  }
  
  exit(0);
}
