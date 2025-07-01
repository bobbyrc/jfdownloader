#!/usr/bin/env dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart' as html_parser;

void main() async {
  print('=== JustFlight Product Details Page Analysis ===');
  
  final dio = Dio();
  final cookieJar = PersistCookieJar();
  dio.interceptors.add(CookieManager(cookieJar));
  
  try {
    // This will help us understand the exact structure of the product details page
    print('Fetching a sample product details page...');
    print('Please provide your login credentials to analyze the actual page structure.');
    
    stdout.write('Email: ');
    final email = stdin.readLineSync() ?? '';
    
    stdout.write('Password: ');
    stdin.echoMode = false;
    final password = stdin.readLineSync() ?? '';
    stdin.echoMode = true;
    print('');
    
    if (email.isEmpty || password.isEmpty) {
      print('Email and password required');
      exit(1);
    }
    
    // Login first
    print('Logging in...');
    final loginResponse = await dio.get('https://www.justflight.com/account/login');
    final loginDoc = html_parser.parse(loginResponse.data);
    
    // Extract form fields
    final form = loginDoc.querySelector('form');
    final hiddenFields = <String, String>{};
    
    form?.querySelectorAll('input[type="hidden"]').forEach((input) {
      final name = input.attributes['name'];
      final value = input.attributes['value'];
      if (name != null && value != null) {
        hiddenFields[name] = value;
      }
    });
    
    final emailField = form?.querySelector('input[type="email"], input[name*="UserName"]')?.attributes['name'];
    final passwordField = form?.querySelector('input[type="password"]')?.attributes['name'];
    final submitField = form?.querySelector('input[type="submit"]')?.attributes['name'];
    
    if (emailField == null || passwordField == null) {
      print('Could not find login fields');
      exit(1);
    }
    
    // Submit login
    final loginData = <String, String>{
      ...hiddenFields,
      emailField: email,
      passwordField: password,
      if (submitField != null) submitField: 'Login',
    };
    
    await dio.post(
      'https://www.justflight.com/account/login',
      data: loginData,
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    
    // Get orders page
    print('Fetching orders page...');
    final ordersResponse = await dio.get('https://www.justflight.com/account/orders');
    final ordersDoc = html_parser.parse(ordersResponse.data);
    
    // Find first product postback
    final productLink = ordersDoc.querySelector('a[href*="javascript:__doPostBack"]');
    if (productLink == null) {
      print('No product links found');
      exit(1);
    }
    
    final href = productLink.attributes['href'] ?? '';
    final postbackMatch = RegExp(r"__doPostBack\('([^']+)','([^']*)'\)").firstMatch(href);
    if (postbackMatch == null) {
      print('Could not parse postback');
      exit(1);
    }
    
    final target = postbackMatch.group(1)!;
    final argument = postbackMatch.group(2) ?? '';
    
    // Extract form state
    final viewState = ordersDoc.querySelector('input[name="__VIEWSTATE"]')?.attributes['value'] ?? '';
    final viewStateGenerator = ordersDoc.querySelector('input[name="__VIEWSTATEGENERATOR"]')?.attributes['value'] ?? '';
    final eventValidation = ordersDoc.querySelector('input[name="__EVENTVALIDATION"]')?.attributes['value'] ?? '';
    
    print('Submitting postback for: ${productLink.text.trim()}');
    
    // Submit postback
    final postbackData = {
      '__EVENTTARGET': target,
      '__EVENTARGUMENT': argument,
      '__VIEWSTATE': viewState,
      '__VIEWSTATEGENERATOR': viewStateGenerator,
      '__EVENTVALIDATION': eventValidation,
    };
    
    final postbackResponse = await dio.post(
      'https://www.justflight.com/account/orders',
      data: postbackData,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: false,
      ),
    );
    
    // Follow redirect to product details
    final location = postbackResponse.headers.value('location');
    if (location == null) {
      print('No redirect found');
      exit(1);
    }
    
    final redirectUrl = location.startsWith('http') ? location : 'https://www.justflight.com$location';
    print('Following redirect to: $redirectUrl');
    
    final detailsResponse = await dio.get(redirectUrl);
    final detailsDoc = html_parser.parse(detailsResponse.data);
    
    // Save the HTML for analysis
    final file = File('product_details_page.html');
    await file.writeAsString(detailsResponse.data);
    print('Saved product details HTML to: ${file.path}');
    
    // Analyze the structure
    print('\n=== PAGE ANALYSIS ===');
    
    // Look for page title
    final title = detailsDoc.querySelector('title')?.text ?? 'No title';
    print('Page title: $title');
    
    // Look for product name
    final h1 = detailsDoc.querySelector('h1')?.text ?? 'No H1';
    print('H1: $h1');
    
    // Look for order information
    print('\nOrder/Product info elements:');
    final orderElements = detailsDoc.querySelectorAll('*').where((e) => 
      e.text.contains('Order') || e.text.contains('JFL') || e.text.contains('Purchased') || e.text.contains('Version')
    );
    for (final elem in orderElements.take(10)) {
      print('  ${elem.localName}: ${elem.text.trim()}');
    }
    
    // Look for download table
    print('\nDownload table structure:');
    final downloadTable = detailsDoc.querySelector('table#downloadLinks');
    if (downloadTable != null) {
      print('Found downloadLinks table');
      final rows = downloadTable.querySelectorAll('tr');
      for (int i = 0; i < rows.length && i < 5; i++) {
        final cells = rows[i].querySelectorAll('td, th');
        print('  Row $i: ${cells.map((c) => c.text.trim()).join(' | ')}');
      }
    } else {
      print('No downloadLinks table found');
    }
    
    // Look for installation content
    print('\nInstallation info structure:');
    final contentDiv = detailsDoc.querySelector('#txtContent, .content, #accountOrderDetails');
    if (contentDiv != null) {
      final text = contentDiv.text;
      final lines = text.split('\n').where((line) => line.trim().isNotEmpty).take(10);
      for (final line in lines) {
        print('  ${line.trim()}');
      }
    }
    
    print('\nDone! Check product_details_page.html for the full structure.');
    
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
