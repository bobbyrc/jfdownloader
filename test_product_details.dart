import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as parser;

void main() async {
  final dio = Dio();
  final cookieJar = CookieJar();
  dio.interceptors.add(CookieManager(cookieJar));

  // Set realistic browser headers
  dio.options = BaseOptions(
    headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    },
    followRedirects: true,
    maxRedirects: 10,
    validateStatus: (status) => status != null && status < 500,
  );

  try {
    // First, need to log in
    print('=== Attempting to log in first ===');
    
    // Get login page
    final loginPageResponse = await dio.get('https://www.justflight.com/account/login');
    final loginDoc = parser.parse(loginPageResponse.data);
    
    // Find the form
    final form = loginDoc.querySelector('form[action*="/account/login"]');
    if (form == null) {
      print('ERROR: Could not find login form');
      return;
    }
    
    // Find all input fields
    final inputs = form.querySelectorAll('input');
    final formData = <String, String>{};
    
    for (final input in inputs) {
      final name = input.attributes['name'];
      final type = input.attributes['type'];
      final value = input.attributes['value'] ?? '';
      
      if (name != null && name.isNotEmpty) {
        if (type == 'hidden' || type == 'submit') {
          formData[name] = value;
        }
      }
    }
    
    // Add credentials
    formData['login[username]'] = 'YOUR_EMAIL'; // Replace with actual email
    formData['login[password]'] = 'YOUR_PASSWORD'; // Replace with actual password
    
    print('Submitting login form with fields: ${formData.keys.toList()}');
    
    // Submit login
    final loginResponse = await dio.post(
      'https://www.justflight.com/account/login',
      data: formData,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
      ),
    );
    
    print('Login response status: ${loginResponse.statusCode}');
    print('Final URL after login: ${loginResponse.realUri}');
    
    // Check if we're logged in by looking for account links
    final responseDoc = parser.parse(loginResponse.data);
    final accountLink = responseDoc.querySelector('a[href*="/account"]');
    if (accountLink == null) {
      print('ERROR: Login failed - no account links found');
      return;
    }
    
    print('✓ Login successful!');
    
    // Now test accessing product details
    print('\n=== Testing product details access ===');
    
    // First, get the orders page to find a product ID
    final ordersResponse = await dio.get('https://www.justflight.com/account/orders');
    final ordersDoc = parser.parse(ordersResponse.data);
    
    print('Orders page status: ${ordersResponse.statusCode}');
    
    // Look for product links or IDs in the orders page
    final productLinks = ordersDoc.querySelectorAll('a[href*="product"]');
    print('Found ${productLinks.length} product-related links');
    
    for (int i = 0; i < productLinks.length && i < 5; i++) {
      final link = productLinks[i];
      final href = link.attributes['href'];
      final text = link.text.trim();
      print('Product link $i: $href - "$text"');
    }
    
    // Look for forms that might submit to productdetails
    final forms = ordersDoc.querySelectorAll('form');
    print('\nFound ${forms.length} forms on orders page');
    
    for (int i = 0; i < forms.length; i++) {
      final form = forms[i];
      final action = form.attributes['action'];
      final method = form.attributes['method'] ?? 'GET';
      print('Form $i: $method $action');
      
      // Look for hidden inputs that might contain product IDs
      final hiddenInputs = form.querySelectorAll('input[type="hidden"]');
      for (final input in hiddenInputs) {
        final name = input.attributes['name'];
        final value = input.attributes['value'];
        print('  Hidden input: $name = $value');
      }
    }
    
    // Try to access the productdetails endpoint directly
    print('\n=== Testing direct access to productdetails ===');
    
    try {
      final productDetailsResponse = await dio.get('https://www.justflight.com/account/productdetails');
      print('Direct GET to productdetails: ${productDetailsResponse.statusCode}');
      
      final detailsDoc = parser.parse(productDetailsResponse.data);
      final title = detailsDoc.querySelector('title')?.text ?? 'No title';
      print('Page title: $title');
      
      // Check if this shows anything useful
      final content = productDetailsResponse.data.toString();
      if (content.contains('product') || content.contains('download')) {
        print('Page seems to contain product/download content');
        
        // Look for forms or inputs that might indicate how to specify a product
        final forms = detailsDoc.querySelectorAll('form');
        print('Found ${forms.length} forms on productdetails page');
        
        for (final form in forms) {
          final action = form.attributes['action'];
          final method = form.attributes['method'] ?? 'GET';
          print('Form: $method $action');
          
          final inputs = form.querySelectorAll('input, select');
          for (final input in inputs) {
            final type = input.attributes['type'];
            final name = input.attributes['name'];
            final value = input.attributes['value'];
            print('  Input: $type $name = $value');
          }
        }
      }
    } catch (e) {
      print('Error accessing productdetails directly: $e');
    }
    
    // Try with some common parameter names
    print('\n=== Testing productdetails with parameters ===');
    
    final testParams = [
      'id=1',
      'productId=1', 
      'orderId=1',
      'product=1',
      'order=1',
    ];
    
    for (final param in testParams) {
      try {
        final url = 'https://www.justflight.com/account/productdetails?$param';
        final response = await dio.get(url);
        print('GET $url: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final doc = parser.parse(response.data);
          final title = doc.querySelector('title')?.text ?? 'No title';
          print('  Title: $title');
          
          // Check for download links
          final downloadLinks = doc.querySelectorAll('a[href*="download"]');
          print('  Found ${downloadLinks.length} download links');
        }
      } catch (e) {
        print('Error with $param: $e');
      }
    }
    
  } catch (e) {
    print('Error: $e');
  }
}
