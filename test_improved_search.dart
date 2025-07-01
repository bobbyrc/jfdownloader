#!/usr/bin/env dart

import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

Future<String?> searchForProductUrl(String productName, Dio dio) async {
  try {
    // URL encode the product name for the search query
    final encodedProductName = Uri.encodeComponent(productName);
    final searchUrl = 'https://www.justflight.com/searchresults?category=products&query=$encodedProductName';
    
    print('Searching for product: $searchUrl');
    
    final response = await dio.get(searchUrl);
    if (response.statusCode == 200) {
      final document = html_parser.parse(response.data);
      
      // Look for the search grid
      final searchGrid = document.querySelector('ul.search-grid');
      if (searchGrid != null) {
        // Look for search items (div.searchedItem)
        final searchItems = searchGrid.querySelectorAll('div.searchedItem');
        print('Found ${searchItems.length} search results');
        
        for (final item in searchItems) {
          // Find the prod_title div within this search item
          final prodTitleDiv = item.querySelector('div.prod_title');
          if (prodTitleDiv != null) {
            // Find the anchor tag with the product link (could be nested in strong tag)
            final productLink = prodTitleDiv.querySelector('a[href]');
            if (productLink != null) {
              final href = productLink.attributes['href'];
              final linkText = productLink.text.trim();
              
              print('Found product link: "$linkText" -> $href');
              
              if (href != null) {
                // Simple fuzzy matching: check if the product name contains key words
                // from the search query or vice versa
                final normalizedSearchName = productName.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
                final normalizedLinkText = linkText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
                
                // Split into words for better matching
                final searchWords = normalizedSearchName.split(RegExp(r'\s+'));
                final linkWords = normalizedLinkText.split(RegExp(r'\s+'));
                
                // Check if there's significant overlap between search terms and product title
                final matchingWords = searchWords.where((word) => 
                  word.length > 2 && linkWords.any((linkWord) => 
                    linkWord.contains(word) || word.contains(linkWord)
                  )
                ).length;
                
                // If we have at least 2 matching words or the link text contains most of the search term
                if (matchingWords >= 2 || normalizedLinkText.contains(normalizedSearchName) || normalizedSearchName.contains(normalizedLinkText)) {
                  print('✓ Selected product: "$linkText" (matching score: $matchingWords words)');
                  
                  // Convert relative URL to absolute URL
                  if (href.startsWith('../')) {
                    return 'https://www.justflight.com/${href.substring(3)}';
                  } else if (href.startsWith('/')) {
                    return 'https://www.justflight.com$href';
                  } else if (href.startsWith('http')) {
                    return href;
                  } else {
                    return 'https://www.justflight.com/$href';
                  }
                } else {
                  print('✗ Skipped product: "$linkText" (low matching score: $matchingWords words)');
                }
              }
            }
          }
        }
        
        // If no good match found but we have results, take the first one as fallback
        if (searchItems.isNotEmpty) {
          final firstItem = searchItems.first;
          final prodTitleDiv = firstItem.querySelector('div.prod_title');
          if (prodTitleDiv != null) {
            final productLink = prodTitleDiv.querySelector('a[href]');
            if (productLink != null) {
              final href = productLink.attributes['href'];
              final linkText = productLink.text.trim();
              
              print('⚠️ Using first result as fallback: "$linkText"');
              
              if (href != null) {
                // Convert relative URL to absolute URL
                if (href.startsWith('../')) {
                  return 'https://www.justflight.com/${href.substring(3)}';
                } else if (href.startsWith('/')) {
                  return 'https://www.justflight.com$href';
                } else if (href.startsWith('http')) {
                  return href;
                } else {
                  return 'https://www.justflight.com/$href';
                }
              }
            }
          }
        }
      }
      
      print('No product found in search results');
      return null;
    } else {
      print('Search request failed: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Error searching for product: $e');
    return null;
  }
}

void main() async {
  final dio = Dio();
  final cookieJar = CookieJar();
  dio.interceptors.add(CookieManager(cookieJar));

  // Test product names from your sample
  final testProducts = [
    'P-51D Mustang',
    'F-15C Eagle',
    'Spitfire Mk IX',
    'Boeing 737',
    'Tornado GR4'
  ];

  for (final productName in testProducts) {
    print('\n=== Testing search for: $productName ===');
    
    final productUrl = await searchForProductUrl(productName, dio);
    
    if (productUrl != null) {
      print('✓ Found product URL: $productUrl');
      
      // Test if the URL is accessible and try to get the image
      try {
        final productResponse = await dio.get(productUrl);
        if (productResponse.statusCode == 200) {
          print('✓ Product page accessible');
          
          final document = html_parser.parse(productResponse.data);
          
          // Look for the fancyPackShot image
          final fancyPackShot = document.getElementById('fancyPackShot');
          if (fancyPackShot != null) {
            final href = fancyPackShot.attributes['href'];
            if (href != null) {
              String imageUrl;
              if (href.startsWith('//')) {
                imageUrl = 'https:$href';
              } else if (href.startsWith('/')) {
                imageUrl = 'https://www.justflight.com$href';
              } else if (href.startsWith('http')) {
                imageUrl = href;
              } else {
                imageUrl = 'https://www.justflight.com/$href';
              }
              print('✓ Found fancyPackShot image: $imageUrl');
            } else {
              print('✗ fancyPackShot element found but no href attribute');
            }
          } else {
            print('✗ No fancyPackShot element found');
            
            // Try fallback images
            final fallbackImages = document.querySelectorAll('img.artwork, .prodImageFloatRight img, img[alt*="aircraft"], img[alt*="plane"]');
            if (fallbackImages.isNotEmpty) {
              print('Found ${fallbackImages.length} fallback images');
              for (final img in fallbackImages) {
                final src = img.attributes['src'];
                if (src != null && src.contains('productimages')) {
                  print('  Fallback image: $src');
                }
              }
            }
          }
        } else {
          print('✗ Product page not accessible: ${productResponse.statusCode}');
        }
      } catch (e) {
        print('✗ Error accessing product page: $e');
      }
    } else {
      print('✗ No product URL found');
    }
    
    // Small delay between requests
    await Future.delayed(Duration(milliseconds: 500));
  }
}
