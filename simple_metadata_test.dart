// Simple test to verify service metadata extraction
void main() {
  print('Testing metadata extraction patterns...');
  
  // Test order number extraction
  final String testProductId = 'JFL2220374062C8F9A7';
  if (testProductId.startsWith('JFL') && testProductId.length >= 16) {
    print('✅ Order number from product ID: $testProductId');
  } else {
    print('❌ Invalid product ID format');
  }
  
  // Test date parsing logic
  final String testContent = '''
    Purchase Date: 15/03/2023
    Order: JFL2220374062C8F9A7
    Version: 0.4.3
    Last updated: 30/06/2025
  ''';
  
  // Extract dates
  final dateMatches = RegExp(r'(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})').allMatches(testContent);
  print('Found ${dateMatches.length} date matches:');
  
  DateTime? mostRecentDate;
  for (final match in dateMatches) {
    try {
      final dateStr = match.group(1)!;
      final parts = dateStr.split(RegExp(r'[\/\-]'));
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (year < 100) year += 2000;
        
        final parsedDate = DateTime(year, month, day);
        if (parsedDate.year >= 2010 && parsedDate.year <= DateTime.now().year) {
          if (mostRecentDate == null || parsedDate.isAfter(mostRecentDate)) {
            mostRecentDate = parsedDate;
          }
          print('  ✅ Valid date: $dateStr -> $parsedDate');
        } else {
          print('  ❌ Date out of range: $dateStr -> $parsedDate');
        }
      }
    } catch (e) {
      print('  ❌ Could not parse date: ${match.group(1)}');
    }
  }
  
  if (mostRecentDate != null) {
    print('✅ Most recent valid date: $mostRecentDate');
  }
  
  // Test version extraction
  final versionMatch = RegExp(r'[vV]ersion\s*:?\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?)').firstMatch(testContent) ??
                      RegExp(r'[vV](\d+\.\d+(?:\.\d+)?)').firstMatch(testContent) ??
                      RegExp(r'(\d+\.\d+\.\d+)').firstMatch(testContent);
  
  if (versionMatch != null) {
    print('✅ Found version: ${versionMatch.group(1)}');
  } else {
    print('❌ No version found');
  }
}
