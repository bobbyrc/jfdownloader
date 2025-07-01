import 'dart:io';
import 'package:html/parser.dart' as html;
import 'lib/services/justflight_service.dart';

Future<void> main() async {
  print('=== Product HTML Analysis Test ===');
  
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
    
    // Get products to find a valid product ID
    print('\n📦 Fetching products...');
    final products = await service.getProducts();
    
    if (products.isEmpty) {
      print('❌ No products found');
      return;
    }
    
    print('✅ Found ${products.length} products');
    
    // Use the first product for analysis
    final product = products.first;
    print('🎯 Analyzing product: ${product.name} (ID: ${product.id})');
    
    // Fetch the product details page HTML
    print('\n🌐 Fetching product details page...');
    final productUrl = 'https://www.justflight.com/product/${product.id}';
    final response = await service.dio.get(productUrl);
    
    if (response.statusCode != 200) {
      print('❌ Failed to fetch product page: ${response.statusCode}');
      return;
    }
    
    final htmlContent = response.data;
    print('✅ Fetched HTML content (${htmlContent.length} characters)');
    
    // Save HTML to file for inspection
    final htmlFile = File('product_details_${product.id}.html');
    await htmlFile.writeAsString(htmlContent);
    print('📄 Saved HTML to: ${htmlFile.path}');
    
    // Parse and analyze the HTML structure
    print('\n🔍 Analyzing HTML structure...');
    final document = html.parse(htmlContent);
    
    // Look for download-related elements
    print('\n📥 Looking for download-related elements:');
    
    // Check for common download selectors
    final downloadSelectors = [
      'a[href*="download"]',
      'a[href*="Download"]',
      '.download',
      '.downloads',
      '.download-link',
      '.download-button',
      'a[href*=".zip"]',
      'a[href*=".exe"]',
      'a[href*=".msi"]',
      'a[href*="file"]',
      'a[href*="installer"]',
      'button[class*="download"]',
      '[data-download]',
    ];
    
    for (final selector in downloadSelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        print('  ✅ Found ${elements.length} elements with selector: $selector');
        for (final element in elements.take(3)) {
          final text = element.text.trim();
          final href = element.attributes['href'];
          print('    - Text: "$text", Href: "$href"');
        }
      } else {
        print('  ❌ No elements found for selector: $selector');
      }
    }
    
    // Look for installation info
    print('\n📖 Looking for installation info elements:');
    
    final installSelectors = [
      '.installation',
      '.install',
      '.instructions',
      '.readme',
      '.manual',
      '.guide',
      '.help',
      '[class*="install"]',
      '[class*="instruction"]',
      'p:contains("install")',
      'div:contains("install")',
      'h1,h2,h3,h4,h5,h6',
    ];
    
    for (final selector in installSelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        print('  ✅ Found ${elements.length} elements with selector: $selector');
        for (final element in elements.take(3)) {
          final text = element.text.trim();
          if (text.isNotEmpty && text.length > 10) {
            print('    - Text: "${text.substring(0, text.length > 100 ? 100 : text.length)}${text.length > 100 ? "..." : ""}"');
          }
        }
      } else {
        print('  ❌ No elements found for selector: $selector');
      }
    }
    
    // Look at all links on the page
    print('\n🔗 All links on the page:');
    final allLinks = document.querySelectorAll('a[href]');
    print('  Found ${allLinks.length} total links');
    
    final relevantLinks = allLinks.where((link) {
      final href = link.attributes['href'] ?? '';
      final text = link.text.trim().toLowerCase();
      return href.contains('download') || 
             href.contains('file') || 
             href.contains('.zip') || 
             href.contains('.exe') || 
             href.contains('.msi') ||
             text.contains('download') ||
             text.contains('install');
    }).toList();
    
    if (relevantLinks.isNotEmpty) {
      print('  📥 Relevant download/install links:');
      for (final link in relevantLinks.take(10)) {
        final text = link.text.trim();
        final href = link.attributes['href'];
        print('    - Text: "$text", Href: "$href"');
      }
    } else {
      print('  ❌ No relevant download/install links found');
    }
    
    // Look for specific content sections
    print('\n📋 Looking for content sections:');
    final contentSelectors = [
      'main',
      '.main-content',
      '.content',
      '.product-content',
      '.product-details',
      '.tab-content',
      '.tabs',
      '.accordion',
      '[role="tabpanel"]',
    ];
    
    for (final selector in contentSelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        print('  ✅ Found ${elements.length} elements with selector: $selector');
        for (final element in elements.take(2)) {
          final childLinks = element.querySelectorAll('a[href]');
          final childText = element.text.trim();
          print('    - Contains ${childLinks.length} links, ${childText.length} characters of text');
          
          // Look for download links within this section
          final downloadLinks = childLinks.where((link) {
            final href = link.attributes['href'] ?? '';
            final text = link.text.trim().toLowerCase();
            return href.contains('download') || 
                   href.contains('file') || 
                   href.contains('.zip') || 
                   href.contains('.exe') || 
                   href.contains('.msi') ||
                   text.contains('download');
          }).toList();
          
          if (downloadLinks.isNotEmpty) {
            print('      📥 Contains ${downloadLinks.length} potential download links');
          }
        }
      }
    }
    
    // Check if this might be a protected/account area
    print('\n🔐 Checking for account/protected content indicators:');
    final protectedIndicators = [
      'account',
      'login',
      'member',
      'customer',
      'my-products',
      'purchases',
      'orders',
    ];
    
    final pageText = document.body?.text.toLowerCase() ?? '';
    final pageHtml = htmlContent.toLowerCase();
    
    for (final indicator in protectedIndicators) {
      if (pageText.contains(indicator) || pageHtml.contains(indicator)) {
        print('  ✅ Found indicator: $indicator');
      }
    }
    
    print('\n📊 Analysis Summary:');
    print('  - Product: ${product.name}');
    print('  - URL: $productUrl');
    print('  - HTML file: ${htmlFile.path}');
    print('  - Total links: ${allLinks.length}');
    print('  - Relevant links: ${relevantLinks.length}');
    print('  - Page text length: ${pageText.length} characters');
    
    print('\n💡 Recommendations:');
    if (relevantLinks.isEmpty) {
      print('  - No obvious download links found - may need to check account/orders page instead');
      print('  - Try looking for AJAX endpoints or JavaScript-generated content');
      print('  - Check if downloads are in a separate protected area');
    } else {
      print('  - Update selectors to match the found patterns');
      print('  - Consider the content sections that contain download links');
    }
    
  } catch (e, stackTrace) {
    print('❌ Error during analysis: $e');
    print('Stack trace: $stackTrace');
  }
}
