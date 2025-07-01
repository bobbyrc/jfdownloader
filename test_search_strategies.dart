#!/usr/bin/env dart

import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

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
  
  // 4. For products with "Black Square", "Steam Gauge", etc., try searching without the prefix
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

void main() async {
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
    print('\n=== Testing search queries for: $productName ===');
    final queries = generateSearchQueries(productName);
    
    for (int i = 0; i < queries.length; i++) {
      print('  ${i + 1}. "${queries[i]}"');
    }
  }
  
  print('\n=== Testing actual searches ===');
  
  final dio = Dio();
  final cookieJar = CookieJar();
  dio.interceptors.add(CookieManager(cookieJar));

  // Test a few problematic products with actual searches
  final searchTests = [
    'Black Square - TBM 850',
    'Steam Gauge Overhaul - Analog Caravan',
  ];

  for (final productName in searchTests) {
    print('\n=== Testing search for: $productName ===');
    final queries = generateSearchQueries(productName);
    
    for (int i = 0; i < queries.length; i++) {
      final query = queries[i];
      final encodedQuery = Uri.encodeComponent(query);
      final searchUrl = 'https://www.justflight.com/searchresults?category=products&query=$encodedQuery';
      
      print('Search ${i + 1}/${queries.length}: "$query"');
      print('  URL: $searchUrl');
      
      try {
        final response = await dio.get(searchUrl);
        if (response.statusCode == 200) {
          final document = html_parser.parse(response.data);
          
          // Look for the search grid
          final searchGrid = document.querySelector('ul.search-grid');
          if (searchGrid != null) {
            final searchItems = searchGrid.querySelectorAll('div.searchedItem');
            print('  Found ${searchItems.length} search results');
            
            for (int j = 0; j < searchItems.length && j < 3; j++) {
              final item = searchItems[j];
              final prodTitleDiv = item.querySelector('div.prod_title');
              if (prodTitleDiv != null) {
                final productLink = prodTitleDiv.querySelector('a[href]');
                if (productLink != null) {
                  final linkText = productLink.text.trim();
                  final href = productLink.attributes['href'];
                  print('    ${j + 1}. "$linkText" -> $href');
                }
              }
            }
            
            if (searchItems.isNotEmpty) {
              print('  ✓ This search query found results!');
              break; // Found results, no need to try more queries
            }
          } else {
            print('  ✗ No search grid found');
          }
        } else {
          print('  ✗ Search failed: ${response.statusCode}');
        }
      } catch (e) {
        print('  ✗ Error: $e');
      }
      
      // Small delay between requests
      await Future.delayed(Duration(milliseconds: 500));
    }
  }
}
