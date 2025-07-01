#!/usr/bin/env dart

/// Generate multiple search queries for better matching
List<String> generateSearchQueries(String productName) {
  final queries = <String>[];
  
  // 1. Original product name
  queries.add(productName);
  
  // 2. Remove parenthetical content like (MSFS), (FSX), etc.
  final withoutParens = productName.replaceAll(RegExp(r'\s*\([^)]+\)\s*'), '').trim();
  if (withoutParens != productName && withoutParens.isNotEmpty) {
    queries.add(withoutParens);
  }
  
  // 3. Remove special characters and normalize
  final normalized = productName.replaceAll(RegExp(r'[^\w\s-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized != productName && normalized.isNotEmpty) {
    queries.add(normalized);
  }
  
  // 4. For products with "Black Square", try searching without the prefix
  if (productName.contains('Black Square')) {
    final withoutPrefix = productName.replaceFirst('Black Square - ', '').trim();
    if (withoutPrefix.isNotEmpty) {
      queries.add(withoutPrefix);
      // Also try with just "Black Square" + key terms
      final keyTerms = withoutPrefix.split(' ').where((word) => word.length > 3).take(2).join(' ');
      if (keyTerms.isNotEmpty) {
        queries.add('Black Square $keyTerms');
      }
    }
  }
  
  // 5. For Steam Gauge products, try different variations
  if (productName.contains('Steam Gauge Overhaul')) {
    final aircraft = productName.replaceFirst('Steam Gauge Overhaul - Analog ', '').trim();
    if (aircraft.isNotEmpty) {
      queries.add('Steam Gauge $aircraft');
      queries.add(aircraft); // Just the aircraft name
    }
  }
  
  // 6. For long product names, try key terms only
  final words = productName.split(' ').where((word) => word.length > 3 && !RegExp(r'[()&,-]').hasMatch(word)).toList();
  if (words.length > 3) {
    // Take first 3 meaningful words
    queries.add(words.take(3).join(' '));
    // Take first and last meaningful words
    if (words.length >= 2) {
      queries.add('${words.first} ${words.last}');
    }
  }
  
  // Remove duplicates while preserving order
  final uniqueQueries = <String>[];
  final seen = <String>{};
  for (final query in queries) {
    if (query.isNotEmpty && !seen.contains(query)) {
      uniqueQueries.add(query);
      seen.add(query);
    }
  }
  
  return uniqueQueries;
}

void main() {
  // Test the query generation for problematic products
  final testProducts = [
    'Black Square - Starship',
    'Black Square - Piston Duke', 
    'Black Square - TBM 850',
    'Steam Gauge Overhaul - Analog Caravan',
    'Steam Gauge Overhaul - Analog King Air',
    'PA-28R Arrow III & Turbo Arrow III/IV Bundle (MSFS)',
    'Real Taxiways USA - Class B, C, D & Non-towered Airports',
    'WB-Sim 172SP Classic Enhancement',
  ];

  for (final productName in testProducts) {
    print('\n=== Search queries for: $productName ===');
    final queries = generateSearchQueries(productName);
    
    for (int i = 0; i < queries.length; i++) {
      print('  ${i + 1}. "${queries[i]}"');
    }
  }
}
