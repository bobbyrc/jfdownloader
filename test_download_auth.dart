import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

void main() async {
  print('Testing JustFlight download authentication...');
  
  // Create a simple HTTP client with cookie support
  final dio = Dio();
  final cookieJar = CookieJar();
  dio.interceptors.add(CookieManager(cookieJar));
  
  try {
    // Read credentials from file
    final credentialsFile = File('credentials.txt');
    if (!await credentialsFile.exists()) {
      print('❌ credentials.txt not found');
      return;
    }
    
    final lines = await credentialsFile.readAsLines();
    if (lines.length < 2) {
      print('❌ credentials.txt needs 2 lines (email and password)');
      return;
    }
    
    final email = lines[0].trim();
    final password = lines[1].trim();
    
    print('🔐 Logging in as ${email.substring(0, 3)}***@${email.split('@').last}');
    
    // Step 1: Get login page
    final loginResponse = await dio.get('https://www.justflight.com/account/login');
    print('✅ Login page loaded: ${loginResponse.statusCode}');
    
    // Extract form data (simplified)
    final loginData = loginResponse.data as String;
    final viewStateMatch = RegExp(r'__VIEWSTATE[^>]*value="([^"]*)"').firstMatch(loginData);
    final viewStateGenMatch = RegExp(r'__VIEWSTATEGENERATOR[^>]*value="([^"]*)"').firstMatch(loginData);
    final eventValidationMatch = RegExp(r'__EVENTVALIDATION[^>]*value="([^"]*)"').firstMatch(loginData);
    
    if (viewStateMatch == null || viewStateGenMatch == null || eventValidationMatch == null) {
      print('❌ Could not extract form data');
      return;
    }
    
    // Step 2: Submit login
    final formData = {
      '__EVENTTARGET': '',
      '__EVENTARGUMENT': '',
      '__VIEWSTATE': viewStateMatch.group(1)!,
      '__VIEWSTATEGENERATOR': viewStateGenMatch.group(1)!,
      '__EVENTVALIDATION': eventValidationMatch.group(1)!,
      'ctl00\$ctl00\$StoreMasterContentPlaceHolder\$PageMasterMainContent\$LoginForm\$UserName': email,
      'ctl00\$ctl00\$StoreMasterContentPlaceHolder\$PageMasterMainContent\$LoginForm\$Password': password,
      'ctl00\$ctl00\$StoreMasterContentPlaceHolder\$PageMasterMainContent\$LoginForm\$btnLogin': 'Login',
    };
    
    final loginSubmitResponse = await dio.post(
      'https://www.justflight.com/account/login',
      data: formData,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: true,
        validateStatus: (status) => status! < 400, // Accept redirects
      ),
    );
    
    print('✅ Login submitted: ${loginSubmitResponse.statusCode}');
    print('Final URL: ${loginSubmitResponse.realUri}');
    
    if (loginSubmitResponse.realUri.toString().contains('/account')) {
      print('✅ Login successful!');
    } else {
      print('❌ Login failed - not redirected to account page');
      return;
    }
    
    // Step 2.5: Verify login by accessing orders page
    print('\n📋 Checking orders page access...');
    try {
      final ordersResponse = await dio.get('https://www.justflight.com/account/orders');
      print('✅ Orders page accessible: ${ordersResponse.statusCode}');
      
      final ordersContent = ordersResponse.data as String;
      if (ordersContent.contains('PA-28-161 Warrior II')) {
        print('✅ Found expected product in orders');
      } else {
        print('⚠️  Could not find expected product in orders');
      }
    } catch (e) {
      print('❌ Orders page failed: $e');
      return;
    }
    
    // Step 3: Test download URLs
    final downloadUrls = [
      'https://www.justflight.com/productdownloads/a86baf5a-117b-4c9c-9c74-f57388ccc356',
      'https://www.justflight.com/productdownloads/3d95d8cb-421c-49d6-a3cd-32ea40031050',
    ];
    
    for (final url in downloadUrls) {
      print('\n🔗 Testing download URL: $url');
      try {
        final downloadResponse = await dio.head(url);
        print('✅ Download URL accessible: ${downloadResponse.statusCode}');
        
        final contentType = downloadResponse.headers.value('content-type');
        final contentLength = downloadResponse.headers.value('content-length');
        final contentDisposition = downloadResponse.headers.value('content-disposition');
        
        print('  Content-Type: $contentType');
        print('  Content-Length: $contentLength bytes');
        print('  Content-Disposition: $contentDisposition');
        
        if (contentType?.contains('application/') == true || 
            contentType?.contains('octet-stream') == true) {
          print('  ✅ Looks like a downloadable file');
        } else {
          print('  ⚠️  Unexpected content type - might be HTML error page');
        }
        
      } catch (e) {
        print('❌ Download URL failed: $e');
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
