#!/usr/bin/env dart

import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

void main() async {
  final dio = Dio();
  final cookieJar = CookieJar();
  dio.interceptors.add(CookieManager(cookieJar));

  // Test product names from your sample
  final testProducts = [
    'P-51D Mustang',
    'F-15C Eagle',
    'Spitfire',
    'Boeing 737'
  ];

  for (final productName in testProducts) {
    print('\n=== Testing search for: $productName ===');
    
    try {
      // URL encode the product name for the search query
      final encodedProductName = Uri.encodeComponent(productName);
      final searchUrl = 'https://www.justflight.com/searchresults?category=products&query=$encodedProductName';
      
      print('Search URL: $searchUrl');
      
      final response = await dio.get(searchUrl);
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);
        
        // Debug: Save the HTML to see the structure
        final debugFile = File('search_results_${productName.replaceAll(RegExp(r'[^\w]'), '_')}.html');
        await debugFile.writeAsString(response.data);
        print('Saved search results to: ${debugFile.path}');
        
        // Look for the search grid
        final searchGrid = document.querySelector('ul.search-grid');
        print('Found search grid: ${searchGrid != null}');
        
        if (searchGrid != null) {
          final allLiElements = searchGrid.querySelectorAll('li');
          print('Found ${allLiElements.length} product items');
          
          // Find the first product result with prod_title
          final prodTitleDiv = searchGrid.querySelector('div.prod_title');
          print('Found prod_title div: ${prodTitleDiv != null}');
          
          if (prodTitleDiv != null) {
            // Find the anchor tag with the product link
            final productLink = prodTitleDiv.querySelector('a[href]');
            print('Found product link: ${productLink != null}');
            
            if (productLink != null) {
              final href = productLink.attributes['href'];
              final text = productLink.text.trim();
              print('Link href: $href');
              print('Link text: $text');
              
              if (href != null) {
                String fullUrl;
                // Convert relative URL to absolute URL
                if (href.startsWith('../')) {
                  fullUrl = 'https://www.justflight.com/${href.substring(3)}';
                } else if (href.startsWith('/')) {
                  fullUrl = 'https://www.justflight.com$href';
                } else if (href.startsWith('http')) {
                  fullUrl = href;
                } else {
                  fullUrl = 'https://www.justflight.com/$href';
                }
                
                print('✓ Found product URL: $fullUrl');
                
                // Test if the URL is accessible
                try {
                  final testResponse = await dio.head(fullUrl);
                  print('✓ Product page accessible (${testResponse.statusCode})');
                } catch (e) {
                  print('✗ Product page not accessible: $e');
                }
              }
            }
          }
          
          // Debug: Show all prod_title divs found
          final allProdTitles = searchGrid.querySelectorAll('div.prod_title');
          print('All prod_title divs found: ${allProdTitles.length}');
          for (int i = 0; i < allProdTitles.length; i++) {
            final div = allProdTitles[i];
            final link = div.querySelector('a[href]');
            if (link != null) {
              print('  $i: ${link.text.trim()} -> ${link.attributes['href']}');
            }
          }
        } else {
          print('✗ No search grid found');
          
          // Debug: Let's see what we do have
          final allUl = document.querySelectorAll('ul');
          print('Found ${allUl.length} ul elements');
          for (final ul in allUl) {
            final classes = ul.attributes['class'] ?? '';
            if (classes.isNotEmpty) {
              print('  ul with classes: $classes');
            }
          }
        }
      } else {
        print('✗ Search request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('✗ Error searching for product: $e');
    }
  }
}
