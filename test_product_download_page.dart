import 'dart:io';
import 'package:html/parser.dart' as html;
import 'lib/services/justflight_service.dart';

Future<void> main() async {
  print('=== Product Download Page Test ===');
  
  // Read credentials
  final credentialsFile = File('credentials.txt');
  if (!credentialsFile.existsSync()) {
    print('❌ credentials.txt not found');
    return;
  }
  
  final lines = await credentialsFile.readAsLines();
  if (lines.length < 2) {
    print('❌ credentials.txt must contain email on first line, password on second line');
    return;
  }
  
  final email = lines[0].trim();
  final password = lines[1].trim();
  
  print('📧 Email: $email');
  print('🔑 Password: ${password.replaceAll(RegExp(r'.'), '*')}');
  
  final service = JustFlightService();
  
  try {
    // Login
    print('\n🔐 Logging in...');
    final loginSuccess = await service.login(email, password);
    
    if (!loginSuccess) {
      print('❌ Login failed');
      return;
    }
    
    print('✅ Login successful');
    
    // Get the orders page to extract postback parameters
    print('\n📦 Fetching orders page...');
    final ordersUrl = 'https://www.justflight.com/account/orders';
    final ordersResponse = await service.dio.get(ordersUrl);
    
    if (ordersResponse.statusCode != 200) {
      print('❌ Failed to fetch orders page: ${ordersResponse.statusCode}');
      return;
    }
    
    final ordersHtml = ordersResponse.data;
    final ordersDoc = html.parse(ordersHtml);
    
    // Extract form data and postback parameters
    final form = ordersDoc.querySelector('form#form1');
    if (form == null) {
      print('❌ Could not find form element');
      return;
    }
    
    final viewState = ordersDoc.querySelector('input[name="__VIEWSTATE"]')?.attributes['value'] ?? '';
    final viewStateGenerator = ordersDoc.querySelector('input[name="__VIEWSTATEGENERATOR"]')?.attributes['value'] ?? '';
    final eventValidation = ordersDoc.querySelector('input[name="__EVENTVALIDATION"]')?.attributes['value'] ?? '';
    
    print('✅ Extracted form data');
    print('  ViewState length: ${viewState.length}');
    print('  ViewStateGenerator: $viewStateGenerator');
    print('  EventValidation length: ${eventValidation.length}');
    
    // Find the first product link
    final productLinks = ordersDoc.querySelectorAll('a[id="btnProductActivation"]');
    if (productLinks.isEmpty) {
      print('❌ No product links found');
      return;
    }
    
    final firstLink = productLinks.first;
    final productName = firstLink.text.trim();
    final href = firstLink.attributes['href'] ?? '';
    
    print('\n🎯 First product: $productName');
    print('  Link: $href');
    
    // Extract the postback parameters from the JavaScript call
    // Format: javascript:__doPostBack('ctl00$ctl00$StoreMasterContentPlaceHolder$PageMasterMainContent$gvOrders$ctl01$btnProductActivation','')
    final jsCallMatch = RegExp(r"__doPostBack\('([^']+)',\s*'([^']*)'\)").firstMatch(href);
    if (jsCallMatch == null) {
      print('❌ Could not parse JavaScript postback call');
      return;
    }
    
    final eventTarget = jsCallMatch.group(1) ?? '';
    final eventArgument = jsCallMatch.group(2) ?? '';
    
    print('  EventTarget: $eventTarget');
    print('  EventArgument: $eventArgument');
    
    // Simulate the postback by sending a POST request
    print('\n🌐 Simulating product link click...');
    
    final postData = {
      '__EVENTTARGET': eventTarget,
      '__EVENTARGUMENT': eventArgument,
      '__VIEWSTATE': viewState,
      '__VIEWSTATEGENERATOR': viewStateGenerator,
      '__EVENTVALIDATION': eventValidation,
    };
    
    // Send the postback request with proper form encoding
    final formData = postData.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    final productResponse = await service.dio.post(
      ordersUrl, // Post back to the same URL
      data: formData,
      options: service.dio.options.copyWith(
        headers: {
          ...service.dio.options.headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
    );
    
    if (productResponse.statusCode != 200) {
      print('❌ Failed to get product page: ${productResponse.statusCode}');
      return;
    }
    
    final productHtml = productResponse.data;
    print('✅ Fetched product page (${productHtml.length} characters)');
    
    // Save the product page HTML
    final productFile = File('product_download_page.html');
    await productFile.writeAsString(productHtml);
    print('📄 Saved product page HTML to: ${productFile.path}');
    
    // Parse and analyze the product download page
    print('\n🔍 Analyzing product download page...');
    final productDoc = html.parse(productHtml);
    
    final title = productDoc.querySelector('title')?.text ?? 'No title';
    print('📝 Page title: $title');
    
    // Look for download links
    print('\n📥 Looking for download links...');
    
    final downloadSelectors = [
      'a[href*="download"]',
      'a[href*="Download"]',
      'a[href*=".zip"]',
      'a[href*=".exe"]',
      'a[href*=".msi"]',
      'a[href*=".pdf"]',
      'a[href*="file"]',
      'a[href*="installer"]',
      'a:contains("Download")',
      'a:contains("download")',
      'button[class*="download"]',
      '.download',
      '.download-link',
      '.file-download',
    ];
    
    final foundDownloads = <String>[];
    
    for (final selector in downloadSelectors) {
      final elements = productDoc.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        print('  ✅ Found ${elements.length} elements with selector: $selector');
        for (final element in elements.take(5)) {
          final text = element.text.trim();
          final href = element.attributes['href'] ?? '';
          final entry = 'Text: "$text", Href: "$href"';
          if (!foundDownloads.contains(entry)) {
            foundDownloads.add(entry);
            print('    - $entry');
          }
        }
      }
    }
    
    if (foundDownloads.isEmpty) {
      print('  ❌ No obvious download links found with standard selectors');
    }
    
    // Look for all links on the page
    print('\n🔗 All links on the product page:');
    final allLinks = productDoc.querySelectorAll('a[href]');
    print('  Found ${allLinks.length} total links');
    
    final relevantLinks = allLinks.where((link) {
      final href = link.attributes['href'] ?? '';
      final text = link.text.trim().toLowerCase();
      
      // Skip navigation and common links
      if (href.isEmpty || text.isEmpty) return false;
      if (href.startsWith('#') || href.startsWith('javascript:')) return false;
      if (href.contains('account') || href.contains('login')) return false;
      
      // Look for download-related content
      return href.toLowerCase().contains('download') || 
             href.toLowerCase().contains('file') || 
             href.contains('.zip') || 
             href.contains('.exe') || 
             href.contains('.msi') || 
             href.contains('.pdf') ||
             text.contains('download') ||
             text.contains('install') ||
             text.contains('file') ||
             text.contains('manual') ||
             text.contains('readme');
    }).toList();
    
    if (relevantLinks.isNotEmpty) {
      print('  📥 Relevant links found:');
      for (final link in relevantLinks.take(10)) {
        final text = link.text.trim();
        final href = link.attributes['href'];
        print('    - Text: "$text", Href: "$href"');
      }
    } else {
      print('  ❌ No relevant download links found');
    }
    
    // Look for installation instructions
    print('\n📖 Looking for installation instructions...');
    final installSelectors = [
      'p:contains("install")',
      'div:contains("install")',
      'span:contains("install")',
      '.instructions',
      '.installation',
      '.readme',
      '.manual',
      '.guide',
      'h1,h2,h3,h4,h5,h6',
    ];
    
    final foundInstructions = <String>[];
    
    for (final selector in installSelectors) {
      final elements = productDoc.querySelectorAll(selector);
      for (final element in elements) {
        final text = element.text.trim();
        if (text.isNotEmpty && 
            text.length > 20 && 
            text.toLowerCase().contains('install') &&
            !foundInstructions.any((instruction) => instruction.contains(text.substring(0, 50)))) {
          foundInstructions.add(text);
          print('  ✅ Found: "${text.length > 200 ? text.substring(0, 200) + "..." : text}"');
        }
      }
    }
    
    if (foundInstructions.isEmpty) {
      print('  ❌ No installation instructions found');
    }
    
    // Look for content sections that might contain downloads
    print('\n📋 Looking for content sections...');
    final contentSelectors = [
      'main',
      '.main-content',
      '.content',
      '.product-content',
      '.download-section',
      '.files-section',
      '.tabs',
      '.tab-content',
      '[role="tabpanel"]',
      '.panel',
      '.accordion',
    ];
    
    for (final selector in contentSelectors) {
      final elements = productDoc.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        print('  ✅ Found ${elements.length} elements with selector: $selector');
        for (final element in elements.take(2)) {
          final childLinks = element.querySelectorAll('a[href]');
          final textLength = element.text.trim().length;
          print('    - Contains ${childLinks.length} links, $textLength characters');
          
          // Count download-related links in this section
          final downloadLinks = childLinks.where((link) {
            final href = link.attributes['href'] ?? '';
            final text = link.text.trim().toLowerCase();
            return href.toLowerCase().contains('download') || 
                   href.contains('.zip') || 
                   href.contains('.exe') || 
                   text.contains('download');
          }).length;
          
          if (downloadLinks > 0) {
            print('      📥 Contains $downloadLinks potential download links');
          }
        }
      }
    }
    
    print('\n📊 Analysis Summary:');
    print('  - Product: $productName');
    print('  - Page title: $title');
    print('  - HTML file: ${productFile.path}');
    print('  - Total links: ${allLinks.length}');
    print('  - Relevant links: ${relevantLinks.length}');
    print('  - Download elements found: ${foundDownloads.length}');
    print('  - Installation instructions: ${foundInstructions.length}');
    
    if (relevantLinks.isNotEmpty || foundDownloads.isNotEmpty) {
      print('\n💡 Success! Found downloadable content. Update selectors to match these patterns.');
    } else {
      print('\n⚠️  No download content found. This page might use AJAX or different structure.');
    }
    
  } catch (e, stackTrace) {
    print('❌ Error during test: $e');
    print('Stack trace: $stackTrace');
  }
}
