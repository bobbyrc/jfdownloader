import 'dart:io';

void main() async {
  print('=== Analyzing Captured HTML Files ===\n');
  
  // Check if we have any captured HTML files
  final files = [
    'login_page.html',
    'login_response.html', 
    'account_page.html',
    'orders_page.html',
    'product_details_page.html',
  ];
  
  for (final fileName in files) {
    final file = File(fileName);
    if (await file.exists()) {
      print('Analyzing $fileName...');
      final content = await file.readAsString();
      
      await analyzeHtmlStructure(fileName, content);
      print('');
    } else {
      print('File $fileName not found');
    }
  }
  
  print('\n=== Next Steps ===');
  print('1. Run the app and navigate to a product details page');
  print('2. Or run test_product_details_html.dart with your credentials to capture the HTML');
  print('3. This will help us understand the actual HTML structure for parsing');
}

Future<void> analyzeHtmlStructure(String fileName, String html) async {
  print('  File size: ${html.length} characters');
  
  // Look for download-related patterns
  final downloadPatterns = [
    r'download',
    r'href="[^"]*\.(exe|msi|zip|rar|7z|pkg|dmg)"',
    r'class="[^"]*download[^"]*"',
    r'id="[^"]*download[^"]*"',
  ];
  
  print('  Download-related content:');
  for (final pattern in downloadPatterns) {
    final matches = RegExp(pattern, caseSensitive: false).allMatches(html);
    if (matches.isNotEmpty) {
      print('    Pattern "$pattern": ${matches.length} matches');
    }
  }
  
  // Look for structural elements
  final tableMatches = RegExp(r'<table[^>]*>', caseSensitive: false).allMatches(html);
  final formMatches = RegExp(r'<form[^>]*>', caseSensitive: false).allMatches(html);
  final linkMatches = RegExp(r'<a[^>]*href="[^"]*"', caseSensitive: false).allMatches(html);
  final buttonMatches = RegExp(r'<(button|input[^>]*type="button")', caseSensitive: false).allMatches(html);
  
  print('  Structure:');
  print('    Tables: ${tableMatches.length}');
  print('    Forms: ${formMatches.length}');
  print('    Links: ${linkMatches.length}');
  print('    Buttons: ${buttonMatches.length}');
  
  // Look for specific JustFlight patterns
  if (html.toLowerCase().contains('justflight')) {
    print('  Contains JustFlight branding: Yes');
  }
  
  if (html.toLowerCase().contains('product')) {
    final productMatches = RegExp(r'product', caseSensitive: false).allMatches(html);
    print('  Product mentions: ${productMatches.length}');
  }
  
  // Look for file extensions in links
  final fileExtensions = ['exe', 'msi', 'zip', 'rar', '7z', 'pkg', 'dmg'];
  for (final ext in fileExtensions) {
    final matches = RegExp('\\.$ext', caseSensitive: false).allMatches(html);
    if (matches.isNotEmpty) {
      print('  .$ext files: ${matches.length}');
    }
  }
}
