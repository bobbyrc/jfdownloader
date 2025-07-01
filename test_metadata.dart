#!/usr/bin/env dart

// Quick test to see what the metadata extraction should find
void main() {
  final productId = 'JFL2220374062C8F9A7';
  
  print('Testing metadata extraction:');
  print('Product ID: $productId');
  
  // Test order number extraction
  if (productId.startsWith('JFL') && productId.length >= 16) {
    print('✅ Order number from product ID: $productId');
  }
  
  // Test date parsing logic
  final testDates = ['25/8/2006', '30/6/2025', '15/3/2023'];
  for (final dateStr in testDates) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (year < 100) year += 2000;
        
        final parsedDate = DateTime(year, month, day);
        
        if (parsedDate.year >= 2010 && parsedDate.year <= DateTime.now().year) {
          print('✅ Valid date: $dateStr -> $parsedDate');
        } else {
          print('❌ Date out of range: $dateStr -> $parsedDate');
        }
      }
    } catch (e) {
      print('❌ Failed to parse: $dateStr');
    }
  }
  
  // Test version patterns
  final testVersions = ['v0.4.3', 'Version: 1.2.3', '0.4.3', 'MSFS 2020 v0.4.3'];
  for (final text in testVersions) {
    final versionMatch = RegExp(r'[vV]ersion\s*:?\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?)').firstMatch(text) ??
                        RegExp(r'[vV](\d+\.\d+(?:\.\d+)?)').firstMatch(text) ??
                        RegExp(r'(\d+\.\d+\.\d+)').firstMatch(text);
    if (versionMatch != null) {
      print('✅ Found version in "$text": ${versionMatch.group(1)}');
    } else {
      print('❌ No version found in: "$text"');
    }
  }
}
