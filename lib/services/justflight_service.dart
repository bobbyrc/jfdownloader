import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/product.dart';
import 'logger_service.dart';

class JustFlightService {
  static final JustFlightService _instance = JustFlightService._internal();
  factory JustFlightService() => _instance;
  JustFlightService._internal();

  late Dio _dio;
  late CookieJar _cookieJar;
  bool _initialized = false;
  final LoggerService _logger = LoggerService();

  static const String baseUrl = 'https://www.justflight.com';
  static const String loginUrl = '$baseUrl/account/login';
  static const String accountUrl = '$baseUrl/account';
  static const String ordersUrl = '$baseUrl/account/orders';

  Future<void> _initialize() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    final cookieDir = Directory(path.join(appDir.path, 'jf_cookies'));
    if (!cookieDir.existsSync()) {
      cookieDir.createSync(recursive: true);
    }

    _cookieJar = PersistCookieJar(storage: FileStorage(cookieDir.path));

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout:
          const Duration(seconds: 15), // Reduced from 30s for faster feedback
      receiveTimeout: const Duration(seconds: 30), // Reduced from 60s
      validateStatus: (status) => status != null && status < 400,
      followRedirects: true,
      maxRedirects: 5,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
        'Cache-Control': 'max-age=0',
      },
    ));

    // Configure connection pool for optimal performance
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.maxConnectionsPerHost =
          4; // Optimized for concurrent image fetching
      client.idleTimeout = const Duration(seconds: 20); // Balanced timeout
      client.connectionTimeout =
          const Duration(seconds: 10); // Faster connection setup
      return client;
    };

    // Add cookie manager with proper persistence
    _dio.interceptors.add(CookieManager(_cookieJar));

    // Add logging interceptor (disabled to reduce log noise)
    // _dio.interceptors.add(LogInterceptor(
    //   requestBody: false,
    //   responseBody: false,
    //   requestHeader: false,
    //   responseHeader: false,
    //   logPrint: (obj) => print('HTTP: $obj'),
    // ));

    _initialized = true;
  }

  Future<bool> login(String email, String password) async {
    await _initialize();

    try {
      _logger.info('Attempting to login to JustFlight...');

      // First, get the login page to extract any CSRF tokens or hidden fields
      final loginPageResponse = await _dio.get(loginUrl);
      final loginDocument = html_parser.parse(loginPageResponse.data);

      _logger.debug('Login page loaded, parsing form...');

      // Use the same robust form detection as the login method
      final forms = loginDocument.querySelectorAll('form');
      if (forms.isEmpty) {
        _logger.warning('No forms found on page');
        return false;
      }

      // Find the form with login fields
      dom.Element? loginForm;
      String? emailFieldName;
      String? passwordFieldName;
      String? submitFieldName;
      String? submitFieldValue;

      for (final form in forms) {
        final inputs = form.querySelectorAll('input');

        String? formEmailField;
        String? formPasswordField;
        String? formSubmitField;
        String? formSubmitValue;

        for (final input in inputs) {
          final type = input.attributes['type']?.toLowerCase() ?? '';
          final name = input.attributes['name'] ?? '';

          if (type == 'email' ||
              name.toLowerCase().contains('email') ||
              name.toLowerCase().contains('username') ||
              name.toLowerCase().contains('user')) {
            formEmailField = name;
          } else if (type == 'password' ||
              name.toLowerCase().contains('password')) {
            formPasswordField = name;
          } else if (type == 'submit') {
            formSubmitField = name;
            formSubmitValue = input.attributes['value'] ?? 'Login';
          }
        }

        // If we found both email and password fields, this is our login form
        if (formEmailField != null && formPasswordField != null) {
          loginForm = form;
          emailFieldName = formEmailField;
          passwordFieldName = formPasswordField;
          submitFieldName = formSubmitField;
          submitFieldValue = formSubmitValue;
          break;
        }
      }

      if (loginForm == null ||
          emailFieldName == null ||
          passwordFieldName == null) {
        _logger.error('Could not find login form with email/password fields');
        return false;
      }

      _logger.debug(
          'Using email field: $emailFieldName, password field: $passwordFieldName');

      // Extract all hidden inputs and form tokens
      final hiddenInputs = loginForm.querySelectorAll('input[type="hidden"]');
      final loginData = <String, String>{};

      for (final input in hiddenInputs) {
        final name = input.attributes['name'];
        final value = input.attributes['value'];
        if (name != null && value != null) {
          loginData[name] = value;
          _logger.debug(
              'Found hidden field: $name = ${value.length > 50 ? '${value.substring(0, 50)}...' : value}');
        }
      }

      // Add the login credentials
      loginData[emailFieldName] = email;
      loginData[passwordFieldName] = password;

      // Add submit button if found
      if (submitFieldName != null && submitFieldValue != null) {
        loginData[submitFieldName] = submitFieldValue;
      }

      _logger.debug('Login data prepared: ${loginData.keys.join(', ')}');

      // Get the form action URL
      String actionUrl = loginForm.attributes['action'] ?? '';
      if (actionUrl.isEmpty) {
        actionUrl = loginUrl;
      } else if (!actionUrl.startsWith('http')) {
        if (actionUrl.startsWith('/')) {
          actionUrl = '$baseUrl$actionUrl';
        } else if (actionUrl.startsWith('./')) {
          // Handle relative URL like "./login"
          actionUrl = loginUrl.substring(0, loginUrl.lastIndexOf('/') + 1) +
              actionUrl.substring(2);
        } else {
          // Relative URL, resolve against current page
          actionUrl =
              loginUrl.substring(0, loginUrl.lastIndexOf('/') + 1) + actionUrl;
        }
      }

      _logger.debug('Submitting to: $actionUrl');

      // Submit login form with manual redirect handling for better cookie preservation
      final loginResponse = await _dio.post(
        actionUrl,
        data: loginData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects:
              false, // Handle redirects manually for better cookie control
        ),
      );

      _logger.debug('Login response status: ${loginResponse.statusCode}');

      // Handle redirects manually to ensure cookies are preserved
      if (loginResponse.statusCode == 302 || loginResponse.statusCode == 301) {
        final location = loginResponse.headers.value('location');
        _logger.debug('Login got redirect to: $location');

        if (location != null) {
          // Follow redirects manually in a loop to handle multiple redirects
          String currentUrl = location;
          int redirectCount = 0;
          const maxRedirects = 5;

          while (redirectCount < maxRedirects) {
            // Build full URL if needed
            if (!currentUrl.startsWith('http')) {
              if (currentUrl.startsWith('/')) {
                currentUrl = '$baseUrl$currentUrl';
              } else {
                currentUrl =
                    '${actionUrl.substring(0, actionUrl.lastIndexOf('/') + 1)}$currentUrl';
              }
            }

            _logger.debug(
                'Following redirect ${redirectCount + 1} to: $currentUrl');
            final redirectResponse = await _dio.get(
              currentUrl,
              options: Options(followRedirects: false),
            );

            _logger.debug(
                'Redirect response status: ${redirectResponse.statusCode}');
            _logger.debug('Response URL: ${redirectResponse.realUri}');

            // Check if this is the final page (no more redirects)
            if (redirectResponse.statusCode == 200) {
              final finalUrl = redirectResponse.realUri.toString();
              if (finalUrl.contains('/account') &&
                  !finalUrl.contains('login')) {
                _logger.info(
                    'Login successful - reached account page after ${redirectCount + 1} redirects');
                return true;
              } else if (finalUrl.contains('login')) {
                _logger.warning('Login failed - redirected back to login page');
                return false;
              } else {
                _logger.warning('Unexpected final page: $finalUrl');
                return false;
              }
            }

            // Check for another redirect
            if (redirectResponse.statusCode == 301 ||
                redirectResponse.statusCode == 302) {
              final nextLocation = redirectResponse.headers.value('location');
              if (nextLocation != null) {
                currentUrl = nextLocation;
                redirectCount++;
                _logger.debug('Got another redirect to: $nextLocation');
              } else {
                _logger.warning('Redirect response but no location header');
                return false;
              }
            } else {
              _logger.warning(
                  'Unexpected status code: ${redirectResponse.statusCode}');
              return false;
            }
          }

          _logger.warning('Too many redirects ($redirectCount)');
          return false;
        } else {
          _logger.warning('No location header in redirect response');
          return false;
        }
      } else {
        _logger.debug('No redirect received, checking response content...');
        final finalUrl = loginResponse.realUri.toString();
        if (finalUrl.contains('/account') && !finalUrl.contains('login')) {
          _logger.info('Login successful - already on account page');
          return true;
        } else if (finalUrl.contains('login')) {
          _logger.warning('Login failed - still on login page');
          return false;
        }
      }

      // Check if login was successful
      final loginSuccess = await isLoggedIn();
      _logger.info('Login success: $loginSuccess');
      return loginSuccess;
    } catch (e) {
      _logger.error('Login error', error: e);
      if (e is DioException) {
        _logger.error(
            'DioException details: ${e.response?.statusCode} - ${e.response?.data}');
      }
      return false;
    }
  }

  Future<bool> isLoggedIn() async {
    await _initialize();

    try {
      _logger.debug('Checking login status...');
      final response = await _dio.get(accountUrl);
      final document = html_parser.parse(response.data);

      // Multiple ways to detect if logged in for JustFlight
      final indicators = [
        // Look for logout link
        document.querySelector('a[href*="logout"]') != null,
        document.querySelector('a[href*="account/logout"]') != null,

        // Look for account-specific content
        document.querySelector('.account-content') != null,
        document.querySelector('.customer-account') != null,
        document.querySelector('.my-account') != null,

        // Look for "My Account" or account navigation
        document.querySelector('a[href*="/account"]') != null &&
            document.querySelector('a[href*="/account/login"]') == null,

        // Check if we're not being redirected to login
        !response.realUri.toString().contains('login'),

        // Look for downloadable products or account sections
        document.querySelector('.downloads') != null,
        document.querySelector('[href*="downloads"]') != null,

        // Check page title doesn't contain "Login"
        !(document
                .querySelector('title')
                ?.text
                .toLowerCase()
                .contains('login') ??
            false),
      ];

      final loggedInCount = indicators.where((i) => i).length;
      final isLoggedIn = loggedInCount >= 2; // Need at least 2 indicators

      _logger.debug(
          'Login indicators found: $loggedInCount/9, logged in: $isLoggedIn');
      _logger.debug('Current URL: ${response.realUri}');

      // Additional check - try to access orders page
      if (isLoggedIn) {
        try {
          final ordersResponse = await _dio.get(ordersUrl);
          final ordersDocument = html_parser.parse(ordersResponse.data);

          // If we can access orders page without being redirected to login, we're logged in
          final ordersAccessible =
              !ordersResponse.realUri.toString().contains('login');
          _logger.debug('Orders page accessible: $ordersAccessible');

          return ordersAccessible;
        } catch (e) {
          _logger.warning('Error accessing orders page: $e');
          return isLoggedIn;
        }
      }

      return isLoggedIn;
    } catch (e) {
      _logger.error('Login check error', error: e);
      return false;
    }
  }

  Future<void> logout() async {
    await _initialize();

    try {
      // Clear cookies
      await _cookieJar.deleteAll();
    } catch (e) {
      _logger.error('Logout error', error: e);
    }
  }

  Future<List<Product>> getProducts({
    bool fetchImages = false,
    void Function(int completed, int total, String message)? onProgressUpdate,
  }) async {
    await _initialize();

    try {
      final response = await _dio.get(ordersUrl);
      final document = html_parser.parse(response.data);

      // Cache the orders HTML and extract postback data for product details
      _cachedOrdersHtml = response.data;
      await _extractAndCachePostbackData(document);
      _logger.info(
          'Cached orders page data and postback information for ${_cachedPostbackData.length} products');

      List<Product> products = _parseProductsFromHtml(document);

      // Optionally fetch high-quality images from product pages
      if (fetchImages) {
        _logger.info(
            'Fetching high-quality images for ${products.length} products concurrently...');

        // Report initial progress
        onProgressUpdate?.call(
            0, products.length, 'Starting image fetching...');

        // Use Stream-based approach (like Go channels) for real-time progress
        final enhancedProducts = <Product>[];
        const maxConcurrent = 3;

        // Create a stream controller to act like a Go channel
        final resultController = StreamController<Product>();

        // Listen to the stream for real-time progress updates
        final streamSubscription = resultController.stream.listen((product) {
          enhancedProducts.add(product);

          // Report progress immediately when each product completes
          onProgressUpdate?.call(enhancedProducts.length, products.length,
              'Processing products...');
        });

        // Simple concurrency control using a counter
        int activeWorkers = 0;
        int completedWorkers = 0;

        for (int i = 0; i < products.length; i++) {
          final product = products[i];
          final productIndex = i;

          // Wait if we've hit our concurrency limit
          while (activeWorkers >= maxConcurrent) {
            await Future.delayed(const Duration(milliseconds: 10));
          }

          // Launch worker and increment counter
          activeWorkers++;
          _fetchProductImageWorker(
                  product, productIndex + 1, products.length, resultController)
              .then((_) {
            activeWorkers--;
            completedWorkers++;
          });
        }

        // Wait for all workers to complete
        while (completedWorkers < products.length) {
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Close the channel and clean up
        await resultController.close();
        await streamSubscription.cancel();

        products = enhancedProducts;
        _logger.info('Image fetching complete!');

        // Report completion
        onProgressUpdate?.call(
            products.length, products.length, 'Image fetching complete!');
      }

      return products;
    } catch (e) {
      _logger.error('Get products error', error: e);
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Worker function that sends results to stream (like Go channel)
  Future<void> _fetchProductImageWorker(Product product, int index, int total,
      StreamController<Product> resultChannel) async {
    try {
      _logger.debug(
          'Fetching image and category for product $index/$total: ${product.name}');

      final result = await fetchProductImageAndCategory(product.name);
      final imageUrl = result['imageUrl'];
      final category = result['category'];

      if (imageUrl != null || category != null) {
        _logger.debug(
            '✓ Found ${imageUrl != null ? 'image' : ''}${imageUrl != null && category != null ? ' and ' : ''}${category != null ? 'category ($category)' : ''} for ${product.name}');

        // Update cached category if we found a better one
        if (category != null && category != 'Unknown' && category.isNotEmpty) {
          _cachedCategories[product.id] = category;
          _logger.debug('Updated cached category for ${product.id}: $category');
        }

        // Cache the image URL for later use in details page
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _cachedImageUrls[product.id] = imageUrl;
          _logger.debug('🖼️ Cached image URL for ${product.id}: $imageUrl');
        }

        // Update product with new information
        var updatedProduct = product;
        if (imageUrl != null) {
          updatedProduct = updatedProduct.copyWith(imageUrl: imageUrl);
        }
        if (category != null) {
          updatedProduct = updatedProduct.copyWith(category: category);
        }

        // Send enhanced product to channel
        resultChannel.add(updatedProduct);
      } else {
        _logger.warning('✗ No image or category found for ${product.name}');
        // Send original product to channel
        resultChannel.add(product);
      }
    } catch (e) {
      _logger.error('✗ Error fetching image/category for ${product.name}',
          error: e);
      // Send original product to channel on error
      resultChannel.add(product);
    }
  }

  List<Product> _parseProductsFromHtml(dom.Document document) {
    final products = <Product>[];

    _logger.debug('Parsing products from orders page...');

    // Look for the orders table specifically
    final ordersTable = document.querySelector('#orders_table');
    if (ordersTable != null) {
      _logger.debug('Found orders table, parsing rows...');

      // Get all table rows in the tbody
      final rows = ordersTable.querySelectorAll('tbody tr');
      _logger.debug('Found ${rows.length} order rows');

      for (int i = 0; i < rows.length; i++) {
        try {
          final product = _parseOrderRow(rows[i], i);
          if (product != null) {
            products.add(product);
            _logger.debug('Parsed product: ${product.name}');
          }
        } catch (e) {
          _logger.warning('Error parsing order row $i: $e');
        }
      }
    } else {
      _logger.debug('Orders table not found, trying alternative selectors...');

      // Fallback to original parsing logic
      final productElements = document.querySelectorAll(
          '.product-item, .download-item, .downloadable-product');

      for (final element in productElements) {
        try {
          final product = _parseProductElement(element);
          if (product != null) {
            products.add(product);
          }
        } catch (e) {
          _logger.warning('Error parsing product element: $e');
        }
      }
    }

    _logger.info('Parsed ${products.length} total products');
    return products;
  }

  Product? _parseOrderRow(dom.Element row, int index) {
    // Orders table structure:
    // Column 0: Favorite (-)
    // Column 1: Status
    // Column 2: Product Title (with download link)
    // Column 3: Order Number
    // Column 4: Date Ordered (PURCHASE DATE)
    // Column 5: Last Downloaded

    final cells = row.querySelectorAll('th, td');
    _logger.debug('Row $index: Found ${cells.length} cells');

    if (cells.length < 4) {
      _logger.debug('Row $index has insufficient columns: ${cells.length}');
      return null;
    }

    // Log all cell contents
    for (int i = 0; i < cells.length; i++) {
      final cellText = cells[i].text.trim();
      final dataSortAttr = cells[i].attributes['data-sort'];
      _logger.debug(
          'Row $index, Cell $i: "$cellText" (data-sort: "$dataSortAttr")');
    }

    // Extract product title from column 2
    final titleCell = cells.length > 2 ? cells[2] : null;
    final titleLink = titleCell?.querySelector('a');
    final titleText = titleLink?.text.trim() ?? titleCell?.text.trim() ?? '';

    if (titleText.isEmpty) {
      _logger.debug('Row $index has no product title');
      return null;
    }

    // Extract order number from column 3
    final orderCell = cells.length > 3 ? cells[3] : null;
    final orderNumber = orderCell?.querySelector('span')?.text.trim() ??
        orderCell?.text.trim() ??
        '';

    // Extract status from column 1
    final statusCell = cells.length > 1 ? cells[1] : null;
    final status = statusCell?.text.trim() ?? '';

    // Extract purchase date from column 4 (Date Ordered) if available
    final dateCell = cells.length > 4 ? cells[4] : null;
    DateTime? purchaseDate;

    _logger.debug(
        'Row $index: Extracting purchase date from column 4 (Date Ordered)');
    if (dateCell != null) {
      _logger.debug(
          'Row $index: Found date cell, checking data-sort attribute...');

      // Try to get the date from the data-sort attribute first (YYYY/MM/DD HH:MM:SS format)
      final dataSortAttr = dateCell.attributes['data-sort'];
      _logger.debug('Row $index: data-sort attribute: "$dataSortAttr"');

      if (dataSortAttr != null &&
          dataSortAttr.trim().isNotEmpty &&
          dataSortAttr != '0000/00/00') {
        try {
          // Parse the ISO-style date from data-sort attribute
          final dateParts = dataSortAttr.split(' ');
          if (dateParts.isNotEmpty) {
            final dateOnly =
                dateParts[0]; // Get just the date part (YYYY/MM/DD)
            final parts = dateOnly.split('/');
            if (parts.length == 3) {
              final year = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final day = int.parse(parts[2]);
              purchaseDate = DateTime(year, month, day);
              _logger.debug(
                  'Row $index: Parsed purchase date from data-sort: $purchaseDate');
            }
          }
        } catch (e) {
          _logger.warning(
              'Row $index: Could not parse date from data-sort "$dataSortAttr": $e');
        }
      }

      // If data-sort parsing failed, try to parse the display date (DD/MM/YYYY format)
      if (purchaseDate == null) {
        final displayDateSpan = dateCell.querySelector('span span');
        final displayDate =
            displayDateSpan?.text.trim() ?? dateCell.text.trim();
        _logger.debug('Row $index: Trying display date: "$displayDate"');

        if (displayDate.isNotEmpty && displayDate != '-') {
          try {
            // Parse UK date format DD/MM/YYYY
            final parts = displayDate.split('/');
            if (parts.length == 3) {
              final day = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final year = int.parse(parts[2]);
              purchaseDate = DateTime(year, month, day);
              _logger.debug(
                  'Row $index: Parsed purchase date from display text: $purchaseDate');
            }
          } catch (e) {
            _logger.warning(
                'Row $index: Could not parse display date "$displayDate": $e');
          }
        }
      }
    } else {
      _logger.debug(
          'Row $index: No date cell found (insufficient columns: ${cells.length})');
    }

    // Create product ID from order number or title
    final productId =
        orderNumber.isNotEmpty ? orderNumber : _generateProductId(titleText);

    // Extract download URL from the title link if it exists
    final downloadUrl = titleLink?.attributes['href'] ?? '';

    final files = <ProductFile>[];
    if (downloadUrl.isNotEmpty && !downloadUrl.startsWith('javascript:')) {
      // Construct proper download URL
      var fullDownloadUrl = downloadUrl;
      if (!downloadUrl.startsWith('http')) {
        // Special handling for productdownloads URLs - they need /account prefix
        if (downloadUrl.startsWith('/productdownloads/')) {
          fullDownloadUrl = '$baseUrl/account$downloadUrl';
        } else if (downloadUrl.startsWith('productdownloads/')) {
          // Handle hrefs like "productdownloads/..." (no leading slash)
          fullDownloadUrl = '$baseUrl/account/$downloadUrl';
        } else if (downloadUrl.startsWith('/')) {
          fullDownloadUrl = '$baseUrl$downloadUrl';
        } else {
          fullDownloadUrl = '$baseUrl/$downloadUrl';
        }
      }

      files.add(ProductFile(
        id: '$productId-download',
        name: '$titleText Download',
        downloadUrl: fullDownloadUrl,
        fileType: _extractFileType(downloadUrl),
        sizeInMB: 0, // Will be determined during download
      ));
    }

    final productCategory = _extractCategory(titleText, '');

    final product = Product(
      id: productId,
      name: titleText,
      description: 'Order: $orderNumber',
      imageUrl: '', // No image available in orders table
      category: productCategory,
      files: files,
      purchaseDate: purchaseDate ?? DateTime.now(),
      version: '1.0',
      sizeInMB: 0.0,
    );

    // Cache the purchase date for use in detailed product fetching
    if (purchaseDate != null) {
      _cachedPurchaseDates[productId] = purchaseDate;
      _logger.debug('Cached purchase date for $productId: $purchaseDate');
    } else {
      _logger.debug('No purchase date to cache for $productId');
    }

    // Cache the category for use in detailed product fetching
    if (productCategory.isNotEmpty) {
      _cachedCategories[productId] = productCategory;
      _logger.debug('Cached category for $productId: $productCategory');
    }

    return product;
  }

  Product? _parseProductElement(dom.Element element) {
    // Extract product information - this will need to be customized based on actual HTML structure
    final nameElement = element.querySelector('.product-name, .title, h2, h3');
    final imageElement = element.querySelector('img');
    final descriptionElement =
        element.querySelector('.description, .product-description');
    final downloadLinks = element.querySelectorAll(
        'a[href*="download"], a[href*=".zip"], a[href*=".exe"]');

    if (nameElement == null) return null;

    final name = nameElement.text.trim();
    final id = _generateProductId(name);
    final imageUrl = imageElement?.attributes['src'] ?? '';
    final description = descriptionElement?.text.trim() ?? '';

    // Parse download files
    final files = <ProductFile>[];
    for (int i = 0; i < downloadLinks.length; i++) {
      final link = downloadLinks[i];
      final fileName =
          link.text.trim().isNotEmpty ? link.text.trim() : 'Download ${i + 1}';
      final downloadUrl = link.attributes['href'] ?? '';

      if (downloadUrl.isNotEmpty) {
        // Construct proper download URL
        var fullDownloadUrl = downloadUrl;
        if (!downloadUrl.startsWith('http')) {
          // Special handling for productdownloads URLs - they need /account prefix
          if (downloadUrl.startsWith('/productdownloads/')) {
            fullDownloadUrl = '$baseUrl/account$downloadUrl';
          } else if (downloadUrl.startsWith('productdownloads/')) {
            // Handle hrefs like "productdownloads/..." (no leading slash)
            fullDownloadUrl = '$baseUrl/account/$downloadUrl';
          } else if (downloadUrl.startsWith('/')) {
            fullDownloadUrl = '$baseUrl$downloadUrl';
          } else {
            fullDownloadUrl = '$baseUrl/$downloadUrl';
          }
        }

        files.add(ProductFile(
          id: '$id-file-$i',
          name: fileName,
          downloadUrl: fullDownloadUrl,
          fileType: _extractFileType(downloadUrl),
          sizeInMB: 0, // Will be determined during download
        ));
      }
    }

    return Product(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl.startsWith('http') ? imageUrl : '$baseUrl$imageUrl',
      category: _extractCategory(name, description),
      files: files,
      purchaseDate: DateTime
          .now(), // Placeholder - would need to be parsed from actual data
      version: '1.0', // Placeholder
      sizeInMB: files.fold(0.0, (sum, file) => sum + file.sizeInMB),
    );
  }

  List<Product> _parseAlternativeProductStructure(dom.Document document) {
    final products = <Product>[];

    // Try to find download links in tables or lists
    final tables = document.querySelectorAll('table');
    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td, th');
        if (cells.length >= 2) {
          final nameCell = cells[0];
          final linkCell = cells.length > 1 ? cells[1] : cells[0];

          final downloadLink = linkCell.querySelector(
              'a[href*="download"], a[href*=".zip"], a[href*=".exe"]');
          if (downloadLink != null) {
            final name = nameCell.text.trim();
            final id = _generateProductId(name);
            final downloadUrl = downloadLink.attributes['href'] ?? '';

            if (name.isNotEmpty && downloadUrl.isNotEmpty) {
              // Construct proper download URL
              var fullDownloadUrl = downloadUrl;
              if (!downloadUrl.startsWith('http')) {
                // Special handling for productdownloads URLs - they need /account prefix
                if (downloadUrl.startsWith('/productdownloads/')) {
                  fullDownloadUrl = '$baseUrl/account$downloadUrl';
                } else {
                  fullDownloadUrl = '$baseUrl/$downloadUrl';
                }
              }

              products.add(Product(
                id: id,
                name: name,
                description: '',
                imageUrl: '',
                category: 'Software',
                files: [
                  ProductFile(
                    id: '$id-file-0',
                    name: downloadLink.text.trim().isNotEmpty
                        ? downloadLink.text.trim()
                        : name,
                    downloadUrl: fullDownloadUrl,
                    fileType: _extractFileType(downloadUrl),
                    sizeInMB: 0,
                  ),
                ],
                purchaseDate: DateTime.now(),
                version: '1.0',
                sizeInMB: 0,
              ));
            }
          }
        }
      }
    }

    return products;
  }

  String _generateProductId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .trim();
  }

  /// Legacy category extraction method using keyword matching.
  /// This is now primarily used as a fallback when breadcrumb data is not available.
  /// The main category extraction now uses _extractCategoryFromBreadcrumbs which is more accurate.
  String _extractCategory(String name, String description) {
    final text = '$name $description'.toLowerCase();

    if (text.contains('aircraft') || text.contains('plane')) return 'Aircraft';
    if (text.contains('airport') || text.contains('scenery')) return 'Scenery';
    if (text.contains('utility') || text.contains('tool')) return 'Utilities';
    if (text.contains('training') || text.contains('tutorial'))
      return 'Training';

    return 'Unknown';
  }

  /// Extract category from JustFlight product page breadcrumbs
  /// Returns a more accurate category based on the navigation path
  String _extractCategoryFromBreadcrumbs(dom.Document document) {
    try {
      // Look for the breadcrumbs panel
      final breadcrumbsPanel = document.querySelector('#panelCrumbs');
      if (breadcrumbsPanel == null) {
        _logger.debug(
            'No breadcrumbs panel found, falling back to basic extraction');
        return 'Unknown';
      }

      // Get all breadcrumb links
      final breadcrumbLinks = breadcrumbsPanel.querySelectorAll('a');
      final breadcrumbTexts =
          breadcrumbLinks.map((link) => link.text.trim()).toList();

      _logger.debug('Found breadcrumbs: ${breadcrumbTexts.join(' > ')}');

      // Map specific JustFlight breadcrumb categories to canonical categories
      for (final breadcrumb in breadcrumbTexts) {
        final breadcrumbLower = breadcrumb.toLowerCase();

        // Direct mapping from JustFlight categories
        if (breadcrumbLower.contains('airliners')) {
          return 'Aircraft';
        }

        if (breadcrumbLower.contains('light aircraft')) {
          return 'Aircraft';
        }

        if (breadcrumbLower.contains('vintage aircraft')) {
          return 'Aircraft';
        }

        if (breadcrumbLower.contains('military')) {
          return 'Aircraft';
        }

        if (breadcrumbLower.contains('scenery and airports')) {
          return 'Scenery';
        }

        if (breadcrumbLower.contains('tools & utilities')) {
          return 'Utilities';
        }

        if (breadcrumbLower.contains('mission packs')) {
          return 'Missions';
        }

        if (breadcrumbLower.contains('traffic ai')) {
          return 'Traffic';
        }

        if (breadcrumbLower.contains('management')) {
          return 'Management';
        }

        if (breadcrumbLower.contains('just flight products')) {
          return 'Just Flight';
        }
      }

      // Fallback: Check for partial matches in case of slight variations
      final fullPath = breadcrumbTexts.join(' ').toLowerCase();

      if (fullPath.contains('aircraft') ||
          fullPath.contains('airliners') ||
          fullPath.contains('vintage') ||
          fullPath.contains('military')) {
        return 'Aircraft';
      }

      if (fullPath.contains('scenery') || fullPath.contains('airports')) {
        return 'Scenery';
      }

      if (fullPath.contains('tools') || fullPath.contains('utilities')) {
        return 'Utilities';
      }

      if (fullPath.contains('mission') || fullPath.contains('missions')) {
        return 'Missions';
      }

      if (fullPath.contains('traffic')) {
        return 'Traffic';
      }

      if (fullPath.contains('management')) {
        return 'Management';
      }

      _logger.debug(
          'No specific category found in breadcrumbs, marking as Unknown');
      return 'Unknown';
    } catch (e) {
      _logger.warning('Error extracting category from breadcrumbs: $e');
      return 'Unknown';
    }
  }

  String _extractFileType(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'unknown';

    final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final extension =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    switch (extension) {
      case 'zip':
      case '7z':
      case 'rar':
        return 'archive';
      case 'exe':
      case 'msi':
        return 'installer';
      case 'pdf':
        return 'manual';
      default:
        return 'file';
    }
  }

  Future<String> getDownloadUrl(String productFileUrl) async {
    await _initialize();

    try {
      // If it's already a direct download URL, return it
      if (productFileUrl.contains('.zip') || productFileUrl.contains('.exe')) {
        return productFileUrl;
      }

      // Otherwise, follow the link to get the actual download URL
      final response = await _dio.get(productFileUrl);
      final document = html_parser.parse(response.data);

      // Look for direct download links
      final downloadLink = document.querySelector(
          'a[href*=".zip"], a[href*=".exe"], a[href*="download"]');
      if (downloadLink != null) {
        final href = downloadLink.attributes['href'];
        if (href != null) {
          return href.startsWith('http') ? href : '$baseUrl$href';
        }
      }

      return productFileUrl;
    } catch (e) {
      _logger.error('Get download URL error', error: e);
      return productFileUrl;
    }
  }

  /// Get the Dio instance for authenticated requests (e.g., downloads)
  Dio getDioInstance() => _dio;

  /// Get detailed product information including all downloadable files and installation info
  // Cache for orders page data to avoid re-fetching
  String? _cachedOrdersHtml;
  final Map<String, Map<String, String>> _cachedPostbackData = {};
  final Map<String, DateTime> _cachedPurchaseDates = {};
  final Map<String, String> _cachedCategories = {};
  final Map<String, String> _cachedImageUrls = {};

  Future<Map<String, dynamic>> getProductDetails(String productId) async {
    _logger.debug('=== getProductDetails called ===');
    _logger.debug('Product ID: $productId');
    _logger.debug(
        'Cached purchase dates available: ${_cachedPurchaseDates.keys.toList()}');
    _logger.debug(
        'Cached categories available: ${_cachedCategories.keys.toList()}');
    _logger.debug('Looking for purchase date for: $productId');

    try {
      _logger.debug('=== Fetching Product Details ===');
      _logger.debug('Product ID: $productId');

      // Check if we have cached postback data for this product
      if (_cachedPostbackData.containsKey(productId)) {
        _logger.debug('Using cached postback data for product: $productId');
        final postbackData = _cachedPostbackData[productId]!;
        return await _submitProductPostback(
          postbackData['target']!,
          postbackData['argument']!,
          postbackData['viewState']!,
          postbackData['viewStateGenerator']!,
          postbackData['eventValidation']!,
          postbackData['productName']!,
          productId, // Pass the order number through
        );
      }

      // If no cached data, try to use cached orders HTML or fetch fresh
      dom.Document ordersDoc;
      if (_cachedOrdersHtml != null) {
        _logger.debug('Using cached orders HTML to extract postback data...');
        ordersDoc = html_parser.parse(_cachedOrdersHtml!);
      } else {
        _logger.debug('No cached data found, fetching fresh orders page...');
        final ordersResponse = await _dio.get('$baseUrl/account/orders');
        ordersDoc = html_parser.parse(ordersResponse.data);
        _cachedOrdersHtml = ordersResponse.data;
      }

      // Extract and cache postback data for all products
      await _extractAndCachePostbackData(ordersDoc);

      // Now try to get the specific product data
      if (_cachedPostbackData.containsKey(productId)) {
        _logger.debug('Found product in cached/fresh data');
        final postbackData = _cachedPostbackData[productId]!;
        return await _submitProductPostback(
          postbackData['target']!,
          postbackData['argument']!,
          postbackData['viewState']!,
          postbackData['viewStateGenerator']!,
          postbackData['eventValidation']!,
          postbackData['productName']!,
          productId, // Add the missing order number argument
        );
      } else {
        throw Exception('Product not found in orders: $productId');
      }
    } catch (e) {
      _logger.error('Error fetching product details', error: e);
      rethrow;
    }
  }

  Future<void> _extractAndCachePostbackData(dom.Document ordersDoc) async {
    _logger.debug('Extracting and caching postback data for all products...');

    // Find the orders table
    final ordersTable = ordersDoc.querySelector('table');
    if (ordersTable == null) {
      throw Exception('Orders table not found');
    }

    final tableRows = ordersTable.querySelectorAll('tr');
    _logger.debug('Processing ${tableRows.length} table rows');

    // Extract form state once
    final viewStateElement =
        ordersDoc.querySelector('input[name="__VIEWSTATE"]');
    final viewStateGeneratorElement =
        ordersDoc.querySelector('input[name="__VIEWSTATEGENERATOR"]');
    final eventValidationElement =
        ordersDoc.querySelector('input[name="__EVENTVALIDATION"]');

    if (viewStateElement == null ||
        viewStateGeneratorElement == null ||
        eventValidationElement == null) {
      throw Exception('Could not find required form fields for postback');
    }

    final viewState = viewStateElement.attributes['value'] ?? '';
    final viewStateGenerator =
        viewStateGeneratorElement.attributes['value'] ?? '';
    final eventValidation = eventValidationElement.attributes['value'] ?? '';

    // Clear existing cache
    _cachedPostbackData.clear();
    _cachedPurchaseDates.clear();
    _cachedCategories.clear();

    // Process each row to find product links
    for (int i = 1; i < tableRows.length; i++) {
      // Skip header row
      final row = tableRows[i];
      final cells = row.querySelectorAll('td, th');

      if (cells.length >= 4) {
        // Extract order number from column 3 (same as _parseOrderRow)
        final orderCell = cells.length > 3 ? cells[3] : null;
        final orderNumber = orderCell?.querySelector('span')?.text.trim() ??
            orderCell?.text.trim() ??
            '';

        // Look for product links in any cell
        for (final cell in cells) {
          final link = cell.querySelector('a[href*="javascript:__doPostBack"]');

          if (link != null) {
            final title = link.text.trim();
            final href = link.attributes['href'] ?? '';

            // Skip navigation links
            if (!title.toLowerCase().contains('log') &&
                !title.toLowerCase().contains('account') &&
                !title.toLowerCase().contains('setting') &&
                title.length > 5) {
              // Parse the JavaScript postback
              final postbackMatch =
                  RegExp(r"__doPostBack\('([^']+)','([^']*)'\)")
                      .firstMatch(href);
              if (postbackMatch != null) {
                final postbackTarget = postbackMatch.group(1)!;
                final postbackArgument = postbackMatch.group(2) ?? '';

                // Use order number as product ID (same as _parseOrderRow)
                final productId = orderNumber.isNotEmpty
                    ? orderNumber
                    : _generateProductId(title);

                // Cache the postback data
                _cachedPostbackData[productId] = {
                  'target': postbackTarget,
                  'argument': postbackArgument,
                  'viewState': viewState,
                  'viewStateGenerator': viewStateGenerator,
                  'eventValidation': eventValidation,
                  'productName': title,
                };

                _logger
                    .debug('Cached postback data for: $title (ID: $productId)');
                break;
              }
            }
          }
        }
      }
    }

    _logger.debug(
        'Cached postback data for ${_cachedPostbackData.length} products');
  }

  Future<Map<String, dynamic>> _submitProductPostback(
    String postbackTarget,
    String postbackArgument,
    String viewState,
    String viewStateGenerator,
    String eventValidation,
    String productName,
    String orderNumber, // Add order number parameter
  ) async {
    _logger.debug('Submitting postback for product: $productName');
    _logger.debug('ViewState length: ${viewState.length}');
    _logger.debug('ViewStateGenerator: $viewStateGenerator');
    _logger.debug('EventValidation length: ${eventValidation.length}');

    // Submit the postback to get the product-specific page
    final formData = {
      '__EVENTTARGET': postbackTarget,
      '__EVENTARGUMENT': postbackArgument,
      '__VIEWSTATE': viewState,
      '__VIEWSTATEGENERATOR': viewStateGenerator,
      '__EVENTVALIDATION': eventValidation,
    };

    _logger.debug('Submitting postback to orders page...');
    final productResponse = await _dio.post(
      '$baseUrl/account/orders',
      data: formData,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: false,
        validateStatus: (status) => status! < 400,
      ),
    );

    // Handle any redirects from the postback
    var currentResponse = productResponse;
    var redirectCount = 0;
    const maxRedirects = 5;

    while ((currentResponse.statusCode == 301 ||
            currentResponse.statusCode == 302) &&
        redirectCount < maxRedirects) {
      final location = currentResponse.headers.value('location');
      if (location == null) break;

      var redirectUrl = location;
      if (!redirectUrl.startsWith('http')) {
        redirectUrl = redirectUrl.startsWith('/')
            ? '$baseUrl$redirectUrl'
            : '$baseUrl/$redirectUrl';
      }

      _logger.debug(
          'Following postback redirect ${redirectCount + 1}: $redirectUrl');

      currentResponse = await _dio.get(
        redirectUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status! < 400,
        ),
      );

      redirectCount++;
    }

    _logger.debug(
        'Product details response status: ${currentResponse.statusCode}');
    _logger.debug('Final URL: ${currentResponse.realUri}');

    if (currentResponse.statusCode != 200) {
      throw Exception(
          'Failed to get product details page: ${currentResponse.statusCode}');
    }

    // Parse the product details page
    final detailsDoc = html_parser.parse(currentResponse.data);
    _logger.debug('Successfully loaded product-specific details page');

    // Extract detailed product information
    // Get the cached purchase date for this product
    final cachedPurchaseDate = _cachedPurchaseDates[orderNumber];
    _logger
        .debug('Looking up cached purchase date for orderNumber: $orderNumber');
    _logger.debug('Found cached purchase date: $cachedPurchaseDate');
    // Get the cached category for this product
    final cachedCategory = _cachedCategories[orderNumber];
    _logger.debug('Looking up cached category for orderNumber: $orderNumber');
    _logger.debug('Found cached category: $cachedCategory');
    final result = _parseProductDetailsPage(
        detailsDoc,
        orderNumber,
        cachedPurchaseDate,
        cachedCategory,
        productName,
        orderNumber); // Pass the correct order number, purchase date, category, original product name, and product ID

    _logger.debug('Parsed product details: ${result.keys.toList()}');
    return result;
  }

  Map<String, dynamic> _parseProductDetailsPage(
      dom.Document document,
      String orderNumber,
      DateTime? cachedPurchaseDate,
      String? cachedCategory,
      String originalProductName,
      String productId) {
    _logger.debug('=== Parsing Product Details Page ===');

    // Look for the product information
    Product? detailedProduct;
    final downloadableFiles = <ProductFile>[];
    final installationInfo = <String, String>{};

    // Use the original product name from the orders table (more reliable than HTML title)
    var productName = originalProductName;
    _logger.debug('Using original product name: $productName');

    // Extract description from the page
    final descriptionElement = document.querySelector(
        '.description, .product-description, .content, #productDescription');
    final description = descriptionElement?.text.trim() ?? '';

    // Extract image URL from the product details page
    String? imageUrl;
    _logger.debug('Looking for product image in details page...');

    // Try the specific selector for the image with id="img0" and class="artwork"
    final imageSelectors = [
      '#img0.artwork', // Most specific: id AND class
      '#img0', // Just the ID
      'img.artwork', // Just the class
      'img[id="img0"]', // Alternative ID selector
    ];

    for (final selector in imageSelectors) {
      final imageElement = document.querySelector(selector);
      if (imageElement != null) {
        final src = imageElement.attributes['src'];
        final id = imageElement.attributes['id'];
        final className = imageElement.attributes['class'];
        _logger.debug('Found image element with selector "$selector"');
        _logger.debug('  - id: "$id"');
        _logger.debug('  - class: "$className"');
        _logger.debug('  - src: "$src"');

        if (src != null && src.isNotEmpty) {
          // Handle different URL formats
          if (src.startsWith('//')) {
            imageUrl = 'https:$src';
          } else if (src.startsWith('/')) {
            imageUrl = '$baseUrl$src';
          } else if (src.startsWith('http')) {
            imageUrl = src;
          } else {
            imageUrl = '$baseUrl/$src';
          }
          _logger.debug('Extracted image URL: $imageUrl');
          break; // Found an image, stop looking
        }
      }
    }

    if (imageUrl == null) {
      _logger.debug('No product image found in details page with any selector');

      // Try to use cached image URL from the product grid/image fetch phase
      final cachedImageUrl = _cachedImageUrls[productId];
      if (cachedImageUrl != null && cachedImageUrl.isNotEmpty) {
        imageUrl = cachedImageUrl;
        _logger.debug('Using cached image URL from grid phase');
      }
    }

    // Use the passed order number directly (it's already the correct JFL order number)
    _logger.debug('Using order number: $orderNumber');

    // Use the cached purchase date from the orders table (authoritative source)
    final purchaseDate = cachedPurchaseDate;
    if (purchaseDate != null) {
      _logger.debug('Using cached purchase date: $purchaseDate');
    } else {
      _logger.warning('No cached purchase date found for product $orderNumber');
    }

    // Use the cached category from the orders table (authoritative source)
    if (cachedCategory != null) {
      _logger.debug('Using cached category: $cachedCategory');
    } else {
      _logger.warning(
          'No cached category found for product $orderNumber, will use fallback');
    }

    String? version;

    // Look for version information
    _logger.debug('Looking for version information in page content...');

    // Try multiple version patterns, including versions from file names
    List<String> versionCandidates = [];

    final pageText = document.body?.text ?? '';

    // Pattern 1: Version: X.X.X
    final versionMatch1 =
        RegExp(r'[vV]ersion\s*:?\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?)')
            .firstMatch(pageText);
    if (versionMatch1 != null) {
      versionCandidates.add(versionMatch1.group(1)!);
      _logger.debug('Found version pattern 1: ${versionMatch1.group(1)}');
    }

    // Pattern 2: vX.X.X
    final versionMatch2 =
        RegExp(r'[vV](\d+\.\d+(?:\.\d+)?)').firstMatch(pageText);
    if (versionMatch2 != null) {
      versionCandidates.add(versionMatch2.group(1)!);
      _logger.debug('Found version pattern 2: ${versionMatch2.group(1)}');
    }

    // Pattern 3: X.X.X (standalone)
    final versionMatches3 = RegExp(r'(\d+\.\d+\.\d+)').allMatches(pageText);
    for (final match in versionMatches3) {
      final candidate = match.group(1)!;
      // Only accept if it looks like a reasonable version number
      final parts = candidate.split('.');
      if (parts.length == 3) {
        final major = int.tryParse(parts[0]);
        final minor = int.tryParse(parts[1]);
        final patch = int.tryParse(parts[2]);
        if (major != null &&
            minor != null &&
            patch != null &&
            major >= 0 &&
            major <= 99 &&
            minor >= 0 &&
            minor <= 99 &&
            patch >= 0 &&
            patch <= 999) {
          versionCandidates.add(candidate);
          _logger.debug('Found version pattern 3: $candidate');
        }
      }
    }

    // Use the first reasonable version found
    if (versionCandidates.isNotEmpty) {
      version = versionCandidates.first;
      _logger.debug('Selected version: $version');
    } else {
      _logger.debug('No version pattern found in page content');
    }

    // Look for the specific download links table
    final downloadTable = document.querySelector('table#downloadLinks');
    if (downloadTable != null) {
      _logger.debug('Found downloadLinks table');

      final rows = downloadTable.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td');

        // Skip header rows and section rows
        if (cells.length >= 4) {
          final versionCell = cells[0];
          final downloadCell = cells[1];
          final dateAddedCell = cells[2];
          final lastDownloadedCell = cells[3];

          // Look for download link in the second cell
          final downloadLink = downloadCell.querySelector('a[href]');
          if (downloadLink != null) {
            final href = downloadLink.attributes['href'] ?? '';
            final fileName = downloadLink.text.trim();
            final version = versionCell.text.trim();
            final dateAdded = dateAddedCell.text.trim();

            if (href.isNotEmpty && fileName.isNotEmpty) {
              // Construct proper full URL
              var fullUrl = href;
              if (!href.startsWith('http')) {
                if (href.startsWith('/')) {
                  // Special handling for productdownloads URLs - they need /account prefix
                  if (href.startsWith('/productdownloads/')) {
                    fullUrl = '$baseUrl/account$href';
                  } else {
                    fullUrl = '$baseUrl$href';
                  }
                } else {
                  // Handle hrefs like "productdownloads/..." (no leading slash)
                  if (href.startsWith('productdownloads/')) {
                    fullUrl = '$baseUrl/account/$href';
                  } else {
                    fullUrl = '$baseUrl/$href';
                  }
                }
              } else {
                // Even if it starts with http, check if it needs fixing
                if (href.contains('/productdownloads/') &&
                    !href.contains('/account/productdownloads/')) {
                  fullUrl = href.replaceAll(
                      '/productdownloads/', '/account/productdownloads/');
                }
              }

              downloadableFiles.add(ProductFile(
                id: '$orderNumber-${downloadableFiles.length}',
                name: fileName,
                downloadUrl: fullUrl,
                fileType: _extractFileType(fileName),
                sizeInMB: 0, // Size will be determined during download
              ));

              _logger.debug(
                  'Found file: $fileName (Version: $version) -> $fullUrl');
            }
          }
        }
      }
    } else {
      _logger.debug(
          'downloadLinks table not found, falling back to general search');

      // Fallback: Look for any download links
      final downloadLinks = document.querySelectorAll(
          'a[href*="download"], a[href*=".zip"], a[href*=".exe"], a[href*=".msi"]');
      _logger.debug('Found ${downloadLinks.length} potential download links');

      for (int i = 0; i < downloadLinks.length; i++) {
        final link = downloadLinks[i];
        final href = link.attributes['href'];
        final fileName = link.text.trim();

        if (href != null && href.isNotEmpty && fileName.isNotEmpty) {
          var fullUrl = href;
          if (!href.startsWith('http')) {
            // Special handling for productdownloads URLs - they need /account prefix
            if (href.startsWith('/productdownloads/')) {
              fullUrl = '$baseUrl/account$href';
            } else if (href.startsWith('/')) {
              fullUrl = '$baseUrl$href';
            } else {
              // Handle hrefs like "productdownloads/..." (no leading slash)
              if (href.startsWith('productdownloads/')) {
                fullUrl = '$baseUrl/account/$href';
              } else {
                fullUrl = '$baseUrl/$href';
              }
            }
          } else {
            fullUrl = href;
          }

          downloadableFiles.add(ProductFile(
            id: '$orderNumber-fallback-file-$i',
            name: fileName,
            downloadUrl: fullUrl,
            fileType: _extractFileType(href),
            sizeInMB: 0, // Size will be determined during download
          ));

          _logger.debug('Found fallback file: $fileName -> $fullUrl');
        }
      }
    }

    // Look for installation information
    // Priority: 1. Ordered lists, 2. Content div, 3. Tables
    bool foundInstallationInfo = false;

    // 1. Check for setup guide in ordered lists (highest priority)
    final setupLists = document.querySelectorAll('ol');
    for (int i = 0; i < setupLists.length && !foundInstallationInfo; i++) {
      final ol = setupLists[i];
      final listItems = ol.querySelectorAll('li');

      if (listItems.isNotEmpty) {
        final instructions = <String>[];
        for (final li in listItems) {
          final text = li.text.trim();
          if (text.isNotEmpty) {
            instructions.add(text);
          }
        }

        if (instructions.isNotEmpty) {
          installationInfo['Installation Instructions'] =
              instructions.join('\n');
          _logger.debug('Found setup guide with ${instructions.length} steps');
          foundInstallationInfo = true;
        }
      }
    }

    // 2. Look for installation information in the content text (if not found above)
    if (!foundInstallationInfo) {
      final contentDiv =
          document.querySelector('#txtContent, .content, #accountOrderDetails');
      if (contentDiv != null) {
        final contentText = contentDiv.text;

        // Extract setup guide if it exists as plain text
        final setupGuideMatch =
            RegExp(r'Setup Guide.*?(?=\n\n|\n[A-Z]|$)', dotAll: true)
                .firstMatch(contentText);
        if (setupGuideMatch != null) {
          installationInfo['Installation Instructions'] =
              setupGuideMatch.group(0)?.trim() ?? '';
          foundInstallationInfo = true;
        }
      }
    }

    // 3. Look for system requirements separately (always check)
    final contentDiv =
        document.querySelector('#txtContent, .content, #accountOrderDetails');
    if (contentDiv != null) {
      final contentText = contentDiv.text;

      // Look for system requirements or compatibility info
      if (contentText.toLowerCase().contains('requirement') ||
          contentText.toLowerCase().contains('compatible') ||
          contentText.toLowerCase().contains('system')) {
        final lines = contentText.split('\n');
        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.toLowerCase().contains('requirement') ||
              trimmedLine.toLowerCase().contains('compatible') ||
              (trimmedLine.toLowerCase().contains('system') &&
                  trimmedLine.length < 200)) {
            installationInfo['System Requirements'] = trimmedLine;
            break;
          }
        }
      }
    }

    // 3. Look for installation info in tables
    final tables = document.querySelectorAll('table');
    for (final table in tables) {
      if (table.attributes['id'] == 'downloadLinks')
        continue; // Skip the downloads table

      final rows = table.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td, th');
        if (cells.length >= 2) {
          final key = cells[0].text.trim();
          final value = cells[1].text.trim();

          if (key.isNotEmpty &&
              value.isNotEmpty &&
              (key.toLowerCase().contains('system') ||
                  key.toLowerCase().contains('requirement') ||
                  key.toLowerCase().contains('version') ||
                  key.toLowerCase().contains('compatible') ||
                  key.toLowerCase().contains('install'))) {
            installationInfo[key] = value;
          }
        }
      }
    }

    // 4. Look for definition lists (dl/dt/dd)
    final definitionLists = document.querySelectorAll('dl');
    for (final dl in definitionLists) {
      final terms = dl.querySelectorAll('dt');
      final definitions = dl.querySelectorAll('dd');

      for (int i = 0; i < terms.length && i < definitions.length; i++) {
        final key = terms[i].text.trim();
        final value = definitions[i].text.trim();

        if (key.isNotEmpty && value.isNotEmpty) {
          installationInfo[key] = value;
        }
      }
    }

    _logger.debug('Found ${installationInfo.length} installation info items');
    _logger.debug('Found ${downloadableFiles.length} downloadable files');

    // Create detailed product with extracted information
    if (productName.isNotEmpty) {
      detailedProduct = Product(
        id: orderNumber,
        name: productName,
        description: description.isNotEmpty ? description : '',
        imageUrl: imageUrl ??
            '', // Use extracted image URL or empty string as fallback
        category: cachedCategory ??
            'Software', // Use cached category or fallback to 'Software'
        files: downloadableFiles,
        purchaseDate: purchaseDate ?? DateTime.now(),
        version: version ?? '1.0',
        sizeInMB:
            downloadableFiles.fold(0.0, (sum, file) => sum + file.sizeInMB),
      );
      _logger.debug(
          'Created detailed product with imageUrl: "${detailedProduct.imageUrl}"');
    }
    return {
      'product': detailedProduct,
      'files': downloadableFiles,
      'installationInfo': installationInfo,
      'orderNumber': orderNumber,
      'purchaseDate': purchaseDate,
      'version': version,
    };
  }

  /// Generate product URL based on product name and category
  String _generateProductUrl(String productName) {
    // Convert product name to URL slug
    String slug = productName
        .toLowerCase()
        // Remove version numbers and simulator tags before processing
        .replaceAll(RegExp(r'\s*\([^)]*\)'),
            '') // Remove anything in parentheses like (MSFS), (X-Plane 12), etc.
        // Handle specific character replacements
        .replaceAll('&', ' and ') // Replace ampersand with ' and '
        .replaceAll('/', '-') // Replace forward slash with hyphen
        .replaceAll(RegExp(r'[^\w\s-]'),
            '') // Remove remaining special characters except spaces and hyphens
        .replaceAll(RegExp(r'\s+'), '-') // Replace spaces with hyphens
        .replaceAll(
            RegExp('-+'), '-') // Replace multiple hyphens with single hyphen
        .replaceAll(RegExp(r'^-|-$'), ''); // Remove leading/trailing hyphens

    // Handle specific patterns that need special treatment
    // Remove hyphens between specific letter-number combinations (e.g., pa-28r -> pa28r)
    slug = slug.replaceAll('pa-28r', 'pa28r');
    slug = slug.replaceAll('pa-28', 'pa28');

    // Determine URL suffix based on product name
    if (productName.contains('(MSFS)')) {
      return 'https://www.justflight.com/product/$slug-microsoft-flight-simulator';
    } else if (productName.contains('(X-Plane 12)')) {
      return 'https://www.justflight.com/product/$slug-xplane-12';
    } else if (productName.contains('(P3D)')) {
      return 'https://www.justflight.com/product/$slug-p3d';
    } else if (productName.contains('(FSX)')) {
      return 'https://www.justflight.com/product/$slug-fsx';
    } else {
      return 'https://www.justflight.com/product/$slug';
    }
  }

  /// Search for product and get the correct URL from search results
  Future<String?> _searchForProductUrl(String productName) async {
    try {
      // Try multiple search strategies
      final searchQueries = _generateSearchQueries(productName);

      for (int i = 0; i < searchQueries.length; i++) {
        final query = searchQueries[i];
        final encodedQuery = Uri.encodeComponent(query);
        final searchUrl =
            'https://www.justflight.com/searchresults?category=products&query=$encodedQuery';

        _logger.debug(
            'Search attempt ${i + 1}/${searchQueries.length}: $searchUrl');

        final response = await _dio.get(
          searchUrl,
          options: Options(
            receiveTimeout:
                const Duration(seconds: 10), // Shorter timeout for search
            sendTimeout: const Duration(seconds: 5),
          ),
        );
        if (response.statusCode == 200) {
          final document = html_parser.parse(response.data);

          // Look for the search grid
          final searchGrid = document.querySelector('ul.search-grid');
          if (searchGrid != null) {
            // Look for search items (div.searchedItem)
            final searchItems = searchGrid.querySelectorAll('div.searchedItem');
            _logger.debug('Found ${searchItems.length} search results');

            if (searchItems.isNotEmpty) {
              final result = _findBestMatch(searchItems, productName, query);
              if (result != null) {
                return result;
              }
            }
          }
        }

        // Try next search query without delay (server-friendly)
      }

      _logger.warning('No product found after trying all search strategies');
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        _logger.warning(
            'Timeout searching for product $productName: ${e.message}');
      } else if (e.response?.statusCode == 500) {
        _logger.warning(
            'Server error (500) searching for product $productName - server may be overloaded');
      } else {
        _logger.warning(
            'Network error searching for product $productName: ${e.message}');
      }
      return null;
    } catch (e) {
      _logger.error('Error searching for product $productName', error: e);
      return null;
    }
  }

  /// Generate multiple search queries for better matching
  List<String> _generateSearchQueries(String productName) {
    final queries = <String>[];

    // 1. Original product name
    queries.add(productName);

    // 2. Remove parenthetical content like (MSFS), (FSX), etc.
    final withoutParens =
        productName.replaceAll(RegExp(r'\s*\([^)]+\)\s*'), '').trim();
    if (withoutParens != productName && withoutParens.isNotEmpty) {
      queries.add(withoutParens);
    }

    // 3. Remove special characters and normalize
    final normalized = productName
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized != productName && normalized.isNotEmpty) {
      queries.add(normalized);
    }

    // 4. For products with "Black Square", "Steam Gauge", etc., try searching without the prefix
    if (productName.contains('Black Square')) {
      final withoutPrefix =
          productName.replaceFirst('Black Square - ', '').trim();
      if (withoutPrefix.isNotEmpty) {
        queries.add(withoutPrefix);
        // Also try with just "Black Square" + key terms
        final keyTerms = withoutPrefix
            .split(' ')
            .where((word) => word.length > 3)
            .take(2)
            .join(' ');
        if (keyTerms.isNotEmpty) {
          queries.add('Black Square $keyTerms');
        }
      }
    }

    // 5. For Steam Gauge products, try different variations
    if (productName.contains('Steam Gauge Overhaul')) {
      final aircraft =
          productName.replaceFirst('Steam Gauge Overhaul - Analog ', '').trim();
      if (aircraft.isNotEmpty) {
        queries.add('Steam Gauge $aircraft');
        queries.add(aircraft); // Just the aircraft name
      }
    }

    // 6. For long product names, try key terms only
    final words = productName
        .split(' ')
        .where((word) => word.length > 3 && !RegExp('[()&,-]').hasMatch(word))
        .toList();
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

  /// Find the best matching product from search results
  String? _findBestMatch(List<dynamic> searchItems, String originalProductName,
      String searchQuery) {
    String? bestMatch;
    int bestScore = 0;
    String? fallbackMatch;

    for (final item in searchItems) {
      // Find the prod_title div within this search item
      final prodTitleDiv = item.querySelector('div.prod_title');
      if (prodTitleDiv != null) {
        // Find the anchor tag with the product link (could be nested in strong tag)
        final productLink = prodTitleDiv.querySelector('a[href]');
        if (productLink != null) {
          final href = productLink.attributes['href'];
          final linkText = productLink.text.trim();

          _logger.debug('Found product link: "$linkText" -> $href');

          if (href != null) {
            // Store first result as fallback
            fallbackMatch ??= _convertToAbsoluteUrl(href);

            // Calculate matching score
            final score = _calculateMatchScore(
                originalProductName, linkText, searchQuery);

            _logger.debug('Match score for "$linkText": $score');

            if (score > bestScore) {
              bestScore = score;
              bestMatch = _convertToAbsoluteUrl(href);
              _logger.debug('✓ New best match: "$linkText" (score: $score)');
            } else {
              _logger.debug('✗ Lower score: "$linkText" (score: $score)');
            }
          }
        }
      }
    }

    // Use best match if score is good enough, otherwise use fallback
    if (bestScore >= 2) {
      return bestMatch;
    } else if (fallbackMatch != null) {
      _logger.warning('⚠️ Using fallback match (best score was $bestScore)');
      return fallbackMatch;
    }

    return null;
  }

  /// Calculate match score between product names
  int _calculateMatchScore(
      String originalProduct, String linkText, String searchQuery) {
    // Normalize both strings
    final normalizedOriginal = originalProduct
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final normalizedLink = linkText
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final normalizedSearch = searchQuery
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Split into words
    final originalWords =
        normalizedOriginal.split(' ').where((w) => w.length > 2).toSet();
    final linkWords =
        normalizedLink.split(' ').where((w) => w.length > 2).toSet();
    final searchWords =
        normalizedSearch.split(' ').where((w) => w.length > 2).toSet();

    int score = 0;

    // Exact match gets highest score
    if (normalizedOriginal == normalizedLink) {
      score += 10;
    }

    // High score for substring matches
    if (normalizedLink.contains(normalizedOriginal) ||
        normalizedOriginal.contains(normalizedLink)) {
      score += 5;
    }

    // Score for word matches with original product name
    final originalMatches = originalWords.intersection(linkWords).length;
    score += originalMatches * 2;

    // Score for word matches with search query
    final searchMatches = searchWords.intersection(linkWords).length;
    score += searchMatches;

    // Bonus for exact word matches in sequence
    final originalWordsList = normalizedOriginal.split(' ');
    final linkWordsList = normalizedLink.split(' ');
    for (int i = 0; i < originalWordsList.length - 1; i++) {
      final phrase = '${originalWordsList[i]} ${originalWordsList[i + 1]}';
      if (normalizedLink.contains(phrase)) {
        score += 3;
      }
    }

    return score;
  }

  /// Convert relative URL to absolute URL
  String _convertToAbsoluteUrl(String href) {
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

  /// Fetch product page image URL
  Future<String?> fetchProductPageImage(String productName) async {
    try {
      await _initialize();

      // First, search for the product to get the correct URL
      final productUrl = await _searchForProductUrl(productName);
      if (productUrl == null) {
        _logger.debug('Could not find product URL for: $productName');
        return null;
      }

      _logger.debug('Found product URL: $productUrl');
      _logger.debug('Fetching product page for image extraction...');

      // Use shorter timeout for image fetching to avoid holding up the queue
      final response = await _dio.get(
        productUrl,
        options: Options(
          receiveTimeout:
              const Duration(seconds: 15), // Shorter timeout for images
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);

        // Look for the fancyPackShot image
        final fancyPackShot = document.getElementById('fancyPackShot');
        if (fancyPackShot != null) {
          final href = fancyPackShot.attributes['href'];
          if (href != null) {
            // Handle both absolute and relative URLs
            if (href.startsWith('//')) {
              return 'https:$href';
            } else if (href.startsWith('/')) {
              return '$baseUrl$href';
            } else if (href.startsWith('http')) {
              return href;
            } else {
              return '$baseUrl/$href';
            }
          }
        }

        // Fallback: look for other product images if fancyPackShot is not found
        final productImages = document.querySelectorAll(
            'img.artwork, .prodImageFloatRight img, img[alt*="aircraft"], img[alt*="plane"]');
        for (final img in productImages) {
          final src = img.attributes['src'];
          if (src != null && src.contains('productimages')) {
            if (src.startsWith('//')) {
              return 'https:$src';
            } else if (src.startsWith('/')) {
              return '$baseUrl$src';
            } else if (src.startsWith('http')) {
              return src;
            }
          }
        }

        _logger.debug('No suitable product image found on page');
        return null;
      } else {
        _logger.warning('Failed to fetch product page: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        _logger.warning(
            'Timeout fetching product page image for $productName: ${e.message}');
      } else if (e.response?.statusCode == 500) {
        _logger.warning(
            'Server error (500) fetching product page for $productName - server may be overloaded');
      } else {
        _logger.warning(
            'Network error fetching product page image for $productName: ${e.message}');
      }
      return null;
    } catch (e) {
      _logger.error('Error fetching product page image for $productName',
          error: e);
      return null;
    }
  }

  /// Fetch additional product information from product page
  Future<Map<String, dynamic>?> fetchProductPageInfo(String productName) async {
    try {
      await _initialize();

      String productUrl = _generateProductUrl(productName);
      _logger.debug('Fetching product info from: $productUrl');

      Response response;
      try {
        response = await _dio.get(productUrl);
      } catch (e) {
        // If it's an MSFS product and the standard URL fails, try the -msfs suffix
        if (productName.contains('(MSFS)') &&
            productUrl.contains('-microsoft-flight-simulator')) {
          final fallbackUrl =
              productUrl.replaceAll('-microsoft-flight-simulator', '-msfs');
          _logger.debug('Primary URL failed, trying fallback: $fallbackUrl');
          response = await _dio.get(fallbackUrl);
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);

        final info = <String, dynamic>{};

        // Extract product description
        final descDiv = document.getElementById('prodDescriptionDiv');
        if (descDiv != null) {
          info['description'] = descDiv.text.trim();
        }

        // Extract product image
        final imageUrl = await fetchProductPageImage(productName);
        if (imageUrl != null) {
          info['imageUrl'] = imageUrl;
        }

        // Extract requirements
        final reqBox = document.getElementById('requirementsBox');
        if (reqBox != null) {
          final requirements = <String>[];
          final listItems = reqBox.querySelectorAll('li');
          for (final item in listItems) {
            requirements.add(item.text.trim());
          }
          info['requirements'] = requirements;
        }

        return info;
      } else {
        _logger.warning(
            'Failed to fetch product page info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.error('Error fetching product page info', error: e);
      return null;
    }
  }

  /// Fetch both product image URL and category from the product page
  /// Returns a map with 'imageUrl' and 'category' keys
  Future<Map<String, String?>> fetchProductImageAndCategory(
      String productName) async {
    try {
      await _initialize();

      // First, search for the product to get the correct URL
      final productUrl = await _searchForProductUrl(productName);
      if (productUrl == null) {
        _logger.debug('Could not find product URL for: $productName');
        return {'imageUrl': null, 'category': null};
      }

      _logger.debug('Found product URL: $productUrl');
      _logger
          .debug('Fetching product page for image and category extraction...');

      // Use shorter timeout for fetching to avoid holding up the queue
      final response = await _dio.get(
        productUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 15), // Shorter timeout
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);

        // Extract category from breadcrumbs
        final category = _extractCategoryFromBreadcrumbs(document);

        // Extract image URL
        String? imageUrl;

        // Look for the fancyPackShot image
        final fancyPackShot = document.getElementById('fancyPackShot');
        if (fancyPackShot != null) {
          final href = fancyPackShot.attributes['href'];
          if (href != null) {
            // Handle both absolute and relative URLs
            if (href.startsWith('//')) {
              imageUrl = 'https:$href';
            } else if (href.startsWith('/')) {
              imageUrl = '$baseUrl$href';
            } else if (href.startsWith('http')) {
              imageUrl = href;
            } else {
              imageUrl = '$baseUrl/$href';
            }
          }
        }

        // Fallback: look for other product images if fancyPackShot is not found
        if (imageUrl == null) {
          final productImages = document.querySelectorAll(
              'img.artwork, .prodImageFloatRight img, img[alt*="aircraft"], img[alt*="plane"]');
          for (final img in productImages) {
            final src = img.attributes['src'];
            if (src != null && src.contains('productimages')) {
              if (src.startsWith('//')) {
                imageUrl = 'https:$src';
                break;
              } else if (src.startsWith('/')) {
                imageUrl = '$baseUrl$src';
                break;
              } else if (src.startsWith('http')) {
                imageUrl = src;
                break;
              }
            }
          }
        }

        _logger.debug(
            'Extracted category: $category, imageUrl: ${imageUrl != null ? 'found' : 'not found'}');

        return {
          'imageUrl': imageUrl,
          'category': category,
        };
      } else {
        _logger.warning('Failed to fetch product page: ${response.statusCode}');
        return {'imageUrl': null, 'category': null};
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        _logger.warning(
            'Timeout fetching product page for $productName: ${e.message}');
      } else if (e.response?.statusCode == 500) {
        _logger.warning(
            'Server error (500) fetching product page for $productName - server may be overloaded');
      } else {
        _logger.warning(
            'Network error fetching product page for $productName: ${e.message}');
      }
      return {'imageUrl': null, 'category': null};
    } catch (e) {
      _logger.error('Error fetching product page for $productName', error: e);
      return {'imageUrl': null, 'category': null};
    }
  }
}
