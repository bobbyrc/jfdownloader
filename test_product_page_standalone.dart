import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

void main() async {
  print('=== Testing JustFlight Product Download Page (Standalone) ===\n');
  
  // Read credentials
  final credentialsFile = File('credentials.txt');
  if (!await credentialsFile.exists()) {
    print('ERROR: credentials.txt file not found');
    print('Please create a credentials.txt file with:');
    print('email@example.com');
    print('your_password');
    return;
  }
  
  final lines = await credentialsFile.readAsLines();
  if (lines.length < 2) {
    print('ERROR: credentials.txt must contain email and password on separate lines');
    return;
  }
  
  final email = lines[0].trim();
  final password = lines[1].trim();
  
  print('Using credentials for: $email');
  
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
    // Step 1: Login
    print('Step 1: Logging in...');
    final loginSuccess = await performLogin(dio, email, password);
    if (!loginSuccess) {
      print('ERROR: Login failed');
      return;
    }
    print('Login successful!\n');
    
    // Step 2: Get orders page
    print('Step 2: Fetching orders page...');
    final ordersResponse = await dio.get('https://www.justflight.com/account/orders');
    if (ordersResponse.statusCode != 200) {
      print('ERROR: Could not access orders page: ${ordersResponse.statusCode}');
      return;
    }
    
    final ordersDoc = html_parser.parse(ordersResponse.data);
    
    // Step 3: Find the first product link in the orders table
    print('Step 3: Finding product links...');
    
    // Look specifically in the orders table
    final ordersTable = ordersDoc.querySelector('table');
    if (ordersTable == null) {
      print('No orders table found');
      return;
    }
    
    final tableRows = ordersTable.querySelectorAll('tr');
    print('Found ${tableRows.length} table rows');
    
    // Find actual product links (skip header row and look for product names)
    dom.Element? productLink;
    String productTitle = '';
    
    for (int i = 1; i < tableRows.length; i++) { // Skip header row
      final row = tableRows[i];
      final cells = row.querySelectorAll('td, th'); // Look in both td and th elements
      
      if (cells.length >= 3) {
        // Look for product links in any cell
        for (final cell in cells) {
          final link = cell.querySelector('a[href*="javascript:__doPostBack"]');
          
          if (link != null) {
            final title = link.text.trim();
            // Skip navigation links like "Log out"
            if (!title.toLowerCase().contains('log') && 
                !title.toLowerCase().contains('account') &&
                !title.toLowerCase().contains('setting') &&
                title.length > 5) {
              productLink = link;
              productTitle = title;
              print('Found product: $productTitle');
              break;
            }
          }
        }
        
        if (productLink != null) break;
      }
    }
    
    if (productLink == null) {
      print('No valid product links found in orders table');
      return;
    }
    
    // Extract the postback information
    final href = productLink.attributes['href'] ?? '';
    print('Product link: $href');
    
    // Parse the JavaScript postback
    final postbackMatch = RegExp(r"__doPostBack\('([^']+)','([^']*)'\)").firstMatch(href);
    if (postbackMatch == null) {
      print('ERROR: Could not parse postback link');
      return;
    }
    
    final eventTarget = postbackMatch.group(1)!;
    final eventArgument = postbackMatch.group(2) ?? '';
    
    print('Event Target: $eventTarget');
    print('Event Argument: $eventArgument');
    
    // Step 4: Get the current page form data
    print('\nStep 4: Extracting form data from orders page...');
    final viewStateElement = ordersDoc.querySelector('input[name="__VIEWSTATE"]');
    final viewStateGeneratorElement = ordersDoc.querySelector('input[name="__VIEWSTATEGENERATOR"]');
    final eventValidationElement = ordersDoc.querySelector('input[name="__EVENTVALIDATION"]');
    
    if (viewStateElement == null || viewStateGeneratorElement == null || eventValidationElement == null) {
      print('ERROR: Could not find required form fields');
      return;
    }
    
    final viewState = viewStateElement.attributes['value'] ?? '';
    final viewStateGenerator = viewStateGeneratorElement.attributes['value'] ?? '';
    final eventValidation = eventValidationElement.attributes['value'] ?? '';
    
    print('ViewState length: ${viewState.length}');
    print('ViewStateGenerator: $viewStateGenerator');
    print('EventValidation length: ${eventValidation.length}');
    
    // Step 5: Submit the postback to get the product page
    print('\nStep 5: Submitting postback for product: $productTitle');
    
    final formData = {
      '__EVENTTARGET': eventTarget,
      '__EVENTARGUMENT': eventArgument,
      '__VIEWSTATE': viewState,
      '__VIEWSTATEGENERATOR': viewStateGenerator,
      '__EVENTVALIDATION': eventValidation,
    };
    
    print('Submitting form data to orders page...');
    final productResponse = await dio.post(
      'https://www.justflight.com/account/orders',
      data: formData,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: false,
        validateStatus: (status) => status! < 400,
      ),
    );
    
    // Handle any redirects from the postback
    var currentResponse = productResponse;
    var redirectCount = 0;
    const maxRedirects = 5;
    
    while ((currentResponse.statusCode == 301 || currentResponse.statusCode == 302) && 
           redirectCount < maxRedirects) {
      final location = currentResponse.headers.value('location');
      if (location == null) break;
      
      var redirectUrl = location;
      if (!redirectUrl.startsWith('http')) {
        redirectUrl = redirectUrl.startsWith('/') 
            ? 'https://www.justflight.com$redirectUrl'
            : 'https://www.justflight.com/$redirectUrl';
      }
      
      print('Following postback redirect ${redirectCount + 1}: $redirectUrl');
      
      currentResponse = await dio.get(
        redirectUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status! < 400,
        ),
      );
      
      redirectCount++;
    }
    
    print('Product page response status: ${currentResponse.statusCode}');
    print('Final URL: ${currentResponse.realUri}');
    
    if (currentResponse.statusCode != 200) {
      print('ERROR: Failed to get product page');
      return;
    }
    
    // Step 6: Save and analyze the product page
    final productHtml = currentResponse.data.toString();
    final productFile = File('actual_product_page.html');
    await productFile.writeAsString(productHtml);
    print('Product page saved to: ${productFile.absolute.path}');
    
    // Step 7: Analyze the content
    print('\nStep 7: Analyzing product page content...');
    await analyzeProductPage(productHtml, productTitle);
    
  } catch (e) {
    print('ERROR: $e');
  }
}

Future<bool> performLogin(Dio dio, String email, String password) async {
  try {
    // Get login page
    final loginPageResponse = await dio.get('https://www.justflight.com/account/login');
    final loginDoc = html_parser.parse(loginPageResponse.data);
    
    // Extract form fields
    final viewStateElement = loginDoc.querySelector('input[name="__VIEWSTATE"]');
    final viewStateGeneratorElement = loginDoc.querySelector('input[name="__VIEWSTATEGENERATOR"]');
    final eventValidationElement = loginDoc.querySelector('input[name="__EVENTVALIDATION"]');
    
    if (viewStateElement == null || viewStateGeneratorElement == null || eventValidationElement == null) {
      print('ERROR: Could not find login form fields');
      return false;
    }
    
    // Submit login
    final loginData = {
      '__EVENTTARGET': '',
      '__EVENTARGUMENT': '',
      '__VIEWSTATE': viewStateElement.attributes['value'] ?? '',
      '__VIEWSTATEGENERATOR': viewStateGeneratorElement.attributes['value'] ?? '',
      '__EVENTVALIDATION': eventValidationElement.attributes['value'] ?? '',
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
        validateStatus: (status) => status! < 400, // Accept redirects
      ),
    );
    
    // Handle redirects manually
    var currentResponse = loginResponse;
    var redirectCount = 0;
    const maxRedirects = 5;
    
    while ((currentResponse.statusCode == 301 || currentResponse.statusCode == 302) && 
           redirectCount < maxRedirects) {
      final location = currentResponse.headers.value('location');
      if (location == null) break;
      
      var redirectUrl = location;
      if (!redirectUrl.startsWith('http')) {
        redirectUrl = redirectUrl.startsWith('/') 
            ? 'https://www.justflight.com$redirectUrl'
            : 'https://www.justflight.com/$redirectUrl';
      }
      
      print('Following redirect ${redirectCount + 1}: $redirectUrl');
      
      currentResponse = await dio.get(
        redirectUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status! < 400,
        ),
      );
      
      redirectCount++;
    }
    
    // Check if we're on the account page
    final finalUrl = currentResponse.realUri.toString();
    print('Final login URL: $finalUrl');
    return finalUrl.contains('/account') && !finalUrl.contains('login') && currentResponse.statusCode == 200;
    
  } catch (e) {
    print('Login error: $e');
    return false;
  }
}

Future<void> analyzeProductPage(String html, String productTitle) async {
  print('Product: $productTitle');
  print('HTML size: ${html.length} characters\n');
  
  final doc = html_parser.parse(html);
  
  // Check if this is actually a product page or if we got redirected
  final pageTitle = doc.querySelector('title')?.text ?? 'No title';
  print('Page title: $pageTitle');
  
  // Look for download-related content
  final downloadPatterns = [
    'download',
    'Download',
    '.exe',
    '.msi', 
    '.zip',
    '.rar',
    '7z',
    'install',
    'Install',
    'file',
    'File',
  ];
  
  print('\nSearching for download-related content:');
  for (final pattern in downloadPatterns) {
    final count = pattern.allMatches(html).length;
    if (count > 0) {
      print('  "$pattern": $count occurrences');
    }
  }
  
  // Look for links
  final allLinks = doc.querySelectorAll('a[href]');
  final downloadLinks = <String>[];
  
  for (final link in allLinks) {
    final href = link.attributes['href'] ?? '';
    final text = link.text.toLowerCase();
    
    if (href.contains('.exe') || href.contains('.msi') || href.contains('.zip') || 
        href.contains('download') || text.contains('download')) {
      downloadLinks.add('${link.text.trim()} -> $href');
    }
  }
  
  print('\nPotential download links found: ${downloadLinks.length}');
  for (int i = 0; i < downloadLinks.length && i < 10; i++) {
    print('  ${i + 1}. ${downloadLinks[i]}');
  }
  
  // Look for tables (might contain file information)
  final tables = doc.querySelectorAll('table');
  print('\nTables found: ${tables.length}');
  
  for (int i = 0; i < tables.length; i++) {
    final table = tables[i];
    final rows = table.querySelectorAll('tr');
    print('  Table ${i + 1}: ${rows.length} rows');
    
    // Check if this table contains file information
    final tableText = table.text.toLowerCase();
    if (tableText.contains('download') || tableText.contains('file') || tableText.contains('install')) {
      print('    ^ Contains download/file/install content');
      
      // Show first few rows
      for (int r = 0; r < rows.length && r < 3; r++) {
        final cells = rows[r].querySelectorAll('td, th');
        final rowText = cells.map((c) => c.text.trim()).join(' | ');
        if (rowText.isNotEmpty) {
          print('    Row ${r + 1}: $rowText');
        }
      }
    }
  }
  
  // Look for forms (might be used for downloads)
  final forms = doc.querySelectorAll('form');
  print('\nForms found: ${forms.length}');
  
  for (int i = 0; i < forms.length; i++) {
    final form = forms[i];
    final action = form.attributes['action'] ?? '';
    final method = form.attributes['method'] ?? 'get';
    print('  Form ${i + 1}: $method $action');
    
    if (action.contains('download') || form.text.toLowerCase().contains('download')) {
      print('    ^ Contains download content');
    }
  }
  
  // Look for divs with specific classes
  final downloadDivs = doc.querySelectorAll('div[class*="download"], div[class*="file"], div[id*="download"], div[id*="file"]');
  print('\nDownload-related divs found: ${downloadDivs.length}');
  
  for (int i = 0; i < downloadDivs.length && i < 5; i++) {
    final div = downloadDivs[i];
    final className = div.attributes['class'] ?? '';
    final id = div.attributes['id'] ?? '';
    final content = div.text.trim();
    print('  Div ${i + 1}: class="$className" id="$id"');
    if (content.length < 200) {
      print('    Content: $content');
    } else {
      print('    Content: ${content.substring(0, 200)}...');
    }
  }
  
  print('\n=== Sample HTML (first 2000 chars) ===');
  print(html.substring(0, 2000.clamp(0, html.length)));
  
  print('\n=== Analysis Complete ===');
  print('Check actual_product_page.html for the full content');
}
