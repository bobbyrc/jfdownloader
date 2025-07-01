import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

void main() async {
  print('=== Testing Product Details HTML Structure ===\n');
  
  final dio = Dio();
  final cookieJar = CookieJar();
  dio.interceptors.add(CookieManager(cookieJar));
  
  // Set realistic headers
  dio.options.headers.addAll({
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  });
  
  try {
    // First login
    print('Step 1: Getting login page...');
    final loginPageResponse = await dio.get('https://www.justflight.com/account/login');
    
    // Parse login form (simplified for this test)
    final loginPageHtml = loginPageResponse.data.toString();
    final viewStateMatch = RegExp(r'name="__VIEWSTATE"[^>]*value="([^"]*)"').firstMatch(loginPageHtml);
    final viewStateGeneratorMatch = RegExp(r'name="__VIEWSTATEGENERATOR"[^>]*value="([^"]*)"').firstMatch(loginPageHtml);
    final eventValidationMatch = RegExp(r'name="__EVENTVALIDATION"[^>]*value="([^"]*)"').firstMatch(loginPageHtml);
    
    if (viewStateMatch == null || viewStateGeneratorMatch == null || eventValidationMatch == null) {
      print('ERROR: Could not extract form fields');
      return;
    }
    
    print('Step 2: Attempting login...');
    
    // Ask for credentials
    stdout.write('Enter email: ');
    final email = stdin.readLineSync() ?? '';
    stdout.write('Enter password: ');
    final password = stdin.readLineSync() ?? '';
    
    // Submit login
    final loginData = {
      '__EVENTTARGET': '',
      '__EVENTARGUMENT': '',
      '__VIEWSTATE': viewStateMatch.group(1),
      '__VIEWSTATEGENERATOR': viewStateGeneratorMatch.group(1),
      '__EVENTVALIDATION': eventValidationMatch.group(1),
      'ctl00\$ctl00\$StoreMasterContentPlaceHolder\$PageMasterMainContent\$LoginForm\$UserName': email,
      'ctl00\$ctl00\$StoreMasterContentPlaceHolder\$PageMasterMainContent\$LoginForm\$Password': password,
      'ctl00\$ctl00\$StoreMasterContentPlaceHolder\$PageMasterMainContent\$LoginForm\$btnLogin': 'Login',
    };
    
    final loginResponse = await dio.post(
      'https://www.justflight.com/account/login',
      data: loginData,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: false,
      ),
    );
    
    // Handle redirects manually to ensure we get to the account page
    var currentUrl = 'https://www.justflight.com/account/login';
    var response = loginResponse;
    var redirectCount = 0;
    
    while (response.statusCode == 302 || response.statusCode == 301) {
      redirectCount++;
      final location = response.headers.value('location');
      if (location == null) break;
      
      if (location.startsWith('/')) {
        currentUrl = 'https://www.justflight.com$location';
      } else {
        currentUrl = location;
      }
      
      print('Redirect $redirectCount: $currentUrl');
      
      response = await dio.get(
        currentUrl,
        options: Options(followRedirects: false),
      );
      
      if (redirectCount > 5) break;
    }
    
    if (response.statusCode != 200) {
      print('ERROR: Login failed with status ${response.statusCode}');
      return;
    }
    
    print('Login successful!\n');
    
    // Now access the product details page
    print('Step 3: Accessing product details page...');
    final detailsResponse = await dio.get('https://www.justflight.com/account/productdetails');
    
    if (detailsResponse.statusCode != 200) {
      print('ERROR: Could not access product details page: ${detailsResponse.statusCode}');
      return;
    }
    
    final detailsHtml = detailsResponse.data.toString();
    print('Product details page loaded successfully (${detailsHtml.length} characters)\n');
    
    // Save the HTML to a file for analysis
    final file = File('product_details_page.html');
    await file.writeAsString(detailsHtml);
    print('HTML saved to: ${file.absolute.path}\n');
    
    // Analyze the structure
    print('=== HTML Structure Analysis ===');
    
    // Look for common download link patterns
    final downloadPatterns = [
      r'download',
      r'href="[^"]*\.(exe|msi|zip|rar|7z|pkg|dmg)"',
      r'class="[^"]*download[^"]*"',
      r'id="[^"]*download[^"]*"',
      r'onclick="[^"]*download[^"]*"',
      r'data-[^=]*="[^"]*download[^"]*"',
    ];
    
    print('Searching for download-related content:');
    for (final pattern in downloadPatterns) {
      final matches = RegExp(pattern, caseSensitive: false).allMatches(detailsHtml);
      if (matches.isNotEmpty) {
        print('  Pattern "$pattern": ${matches.length} matches');
        for (final match in matches.take(3)) {
          final context = detailsHtml.substring(
            (match.start - 50).clamp(0, detailsHtml.length),
            (match.end + 50).clamp(0, detailsHtml.length),
          );
          print('    Context: ...${context.replaceAll('\n', ' ')}...');
        }
      }
    }
    
    // Look for table structures
    final tableMatches = RegExp(r'<table[^>]*>(.*?)</table>', caseSensitive: false, dotAll: true).allMatches(detailsHtml);
    print('\nFound ${tableMatches.length} tables');
    
    // Look for list structures
    final listMatches = RegExp(r'<(ul|ol)[^>]*>(.*?)</\1>', caseSensitive: false, dotAll: true).allMatches(detailsHtml);
    print('Found ${listMatches.length} lists');
    
    // Look for div structures that might contain files
    final divMatches = RegExp(r'<div[^>]*class="[^"]*file[^"]*"[^>]*>(.*?)</div>', caseSensitive: false, dotAll: true).allMatches(detailsHtml);
    print('Found ${divMatches.length} file-related divs');
    
    // Look for links
    final linkMatches = RegExp(r'<a[^>]*href="[^"]*"[^>]*>', caseSensitive: false).allMatches(detailsHtml);
    print('Found ${linkMatches.length} total links');
    
    // Look for forms (might be used for downloads)
    final formMatches = RegExp(r'<form[^>]*>(.*?)</form>', caseSensitive: false, dotAll: true).allMatches(detailsHtml);
    print('Found ${formMatches.length} forms');
    
    // Look for buttons
    final buttonMatches = RegExp(r'<(button|input[^>]*type="button")[^>]*>', caseSensitive: false).allMatches(detailsHtml);
    print('Found ${buttonMatches.length} buttons');
    
    print('\n=== Page Title and Headers ===');
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false).firstMatch(detailsHtml);
    if (titleMatch != null) {
      print('Title: ${titleMatch.group(1)?.trim()}');
    }
    
    final headerMatches = RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>', caseSensitive: false).allMatches(detailsHtml);
    print('Headers found: ${headerMatches.length}');
    for (final match in headerMatches.take(5)) {
      print('  ${match.group(0)?.replaceAll('\n', ' ').trim()}');
    }
    
    print('\n=== Sample of the HTML (first 1000 chars) ===');
    print(detailsHtml.substring(0, 1000.clamp(0, detailsHtml.length)));
    
    print('\nAnalysis complete! Check product_details_page.html for the full HTML structure.');
    
  } catch (e) {
    print('ERROR: $e');
  }
}
