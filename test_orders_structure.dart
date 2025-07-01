import 'dart:io';
import 'package:html/parser.dart' as html;
import 'lib/services/justflight_service.dart';

Future<void> main() async {
  print('=== Product Structure Analysis Test ===');
  
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
    
    // Fetch the orders page directly and analyze its structure
    print('\n📦 Fetching orders page HTML...');
    final ordersUrl = 'https://www.justflight.com/account/orders';
    final ordersResponse = await service.dio.get(ordersUrl);
    
    if (ordersResponse.statusCode != 200) {
      print('❌ Failed to fetch orders page: ${ordersResponse.statusCode}');
      return;
    }
    
    final ordersHtml = ordersResponse.data;
    print('✅ Fetched orders HTML (${ordersHtml.length} characters)');
    
    // Save orders HTML
    final ordersFile = File('orders_page.html');
    await ordersFile.writeAsString(ordersHtml);
    print('📄 Saved orders HTML to: ${ordersFile.path}');
    
    // Parse the orders page
    final ordersDoc = html.parse(ordersHtml);
    
    print('\n🔍 Analyzing orders page structure...');
    
    // Look for tables
    final tables = ordersDoc.querySelectorAll('table');
    print('📊 Found ${tables.length} tables');
    
    for (int i = 0; i < tables.length; i++) {
      final table = tables[i];
      final rows = table.querySelectorAll('tr');
      print('  Table ${i + 1}: ${rows.length} rows');
      
      // Analyze table structure
      if (rows.isNotEmpty) {
        final headerRow = rows[0];
        final headers = headerRow.querySelectorAll('th, td');
        print('    Headers: ${headers.map((h) => h.text.trim()).join(' | ')}');
        
        // Look at first few data rows
        for (int j = 1; j < rows.length && j <= 3; j++) {
          final row = rows[j];
          final cells = row.querySelectorAll('td, th');
          print('    Row ${j}: ${cells.map((c) => c.text.trim()).join(' | ')}');
          
          // Look for links in this row
          final links = row.querySelectorAll('a[href]');
          for (final link in links) {
            final href = link.attributes['href'];
            final text = link.text.trim();
            print('      Link: "$text" -> "$href"');
          }
        }
      }
    }
    
    // Look for all links on the orders page
    print('\n🔗 All links on orders page:');
    final allLinks = ordersDoc.querySelectorAll('a[href]');
    print('  Found ${allLinks.length} total links');
    
    final productLinks = <String, String>{};
    
    for (final link in allLinks) {
      final href = link.attributes['href'] ?? '';
      final text = link.text.trim();
      
      // Skip empty or navigation links
      if (text.isEmpty || href.isEmpty) continue;
      if (href.startsWith('#') || href.startsWith('javascript:')) continue;
      if (href.contains('account') || href.contains('login') || href.contains('logout')) continue;
      
      // Look for potential product links
      if (href.contains('product') || href.contains('download') || text.toLowerCase().contains('download')) {
        productLinks[text] = href;
        print('  🎯 Product/Download link: "$text" -> "$href"');
      }
    }
    
    if (productLinks.isEmpty) {
      print('  ❌ No obvious product/download links found');
      
      // Let's look for other patterns
      print('\n🔍 Looking for other patterns...');
      
      // Check for JavaScript or AJAX patterns
      final scriptTags = ordersDoc.querySelectorAll('script');
      print('  Found ${scriptTags.length} script tags');
      
      bool foundDownloadPatterns = false;
      for (final script in scriptTags) {
        final scriptContent = script.text;
        if (scriptContent.contains('download') || scriptContent.contains('product')) {
          foundDownloadPatterns = true;
          print('  ✅ Found download/product patterns in JavaScript');
          
          // Extract relevant parts
          final lines = scriptContent.split('\n');
          for (final line in lines) {
            if (line.toLowerCase().contains('download') || line.toLowerCase().contains('product')) {
              print('    - ${line.trim()}');
            }
          }
          break;
        }
      }
      
      if (!foundDownloadPatterns) {
        print('  ❌ No download patterns found in JavaScript');
      }
      
    } else {
      // Try to fetch one of the product links
      print('\n🌐 Testing first product link...');
      final firstLink = productLinks.entries.first;
      print('  Testing: "${firstLink.key}" -> "${firstLink.value}"');
      
      String fullUrl = firstLink.value;
      if (!fullUrl.startsWith('http')) {
        if (fullUrl.startsWith('/')) {
          fullUrl = 'https://www.justflight.com${fullUrl}';
        } else {
          fullUrl = 'https://www.justflight.com/${fullUrl}';
        }
      }
      
      try {
        final productResponse = await service.dio.get(fullUrl);
        print('  ✅ Successfully fetched product page (${productResponse.data.length} characters)');
        
        // Save this product page
        final productFile = File('actual_product_page.html');
        await productFile.writeAsString(productResponse.data);
        print('  📄 Saved product HTML to: ${productFile.path}');
        
        // Quick analysis of the product page
        final productDoc = html.parse(productResponse.data);
        final productTitle = productDoc.querySelector('title')?.text ?? 'No title';
        print('  📝 Product page title: $productTitle');
        
        // Look for download links on the product page
        final downloadLinks = productDoc.querySelectorAll('a[href]').where((link) {
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
        
        print('  📥 Found ${downloadLinks.length} potential download links:');
        for (final link in downloadLinks.take(5)) {
          final href = link.attributes['href'];
          final text = link.text.trim();
          print('    - "$text" -> "$href"');
        }
        
      } catch (e) {
        print('  ❌ Failed to fetch product page: $e');
      }
    }
    
    print('\n📊 Analysis Summary:');
    print('  - Orders page: ${ordersFile.path}');
    print('  - Tables found: ${tables.length}');
    print('  - Total links: ${allLinks.length}');
    print('  - Product/download links: ${productLinks.length}');
    
    if (productLinks.isNotEmpty) {
      print('\n💡 Recommendations:');
      print('  - Use the found product links instead of constructing URLs from product IDs');
      print('  - Update the product parsing to extract these actual links');
      print('  - The links might lead directly to download pages or product detail pages with downloads');
    }
    
  } catch (e, stackTrace) {
    print('❌ Error during analysis: $e');
    print('Stack trace: $stackTrace');
  }
}
