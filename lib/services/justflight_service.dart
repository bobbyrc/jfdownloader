import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/product.dart';

class JustFlightService {
  static final JustFlightService _instance = JustFlightService._internal();
  factory JustFlightService() => _instance;
  JustFlightService._internal();

  late Dio _dio;
  late CookieJar _cookieJar;
  bool _initialized = false;

  static const String baseUrl = 'https://www.justflight.com';
  static const String loginUrl = '$baseUrl/customer/account/login/';
  static const String accountUrl = '$baseUrl/customer/account/';
  static const String downloadsUrl = '$baseUrl/customer/account/downloadable-products/';

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
      followRedirects: true,
      maxRedirects: 5,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      },
    ));

    _dio.interceptors.add(CookieManager(_cookieJar));
    
    // Add logging interceptor for debugging
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      requestHeader: false,
      responseHeader: false,
    ));

    _initialized = true;
  }

  Future<bool> login(String email, String password) async {
    await _initialize();

    try {
      // First, get the login page to extract any CSRF tokens or hidden fields
      final loginPageResponse = await _dio.get(loginUrl);
      final loginDocument = html_parser.parse(loginPageResponse.data);

      // Extract form token if present
      String? formKey;
      final formKeyInput = loginDocument.querySelector('input[name="form_key"]');
      if (formKeyInput != null) {
        formKey = formKeyInput.attributes['value'];
      }

      // Prepare login data
      final loginData = <String, dynamic>{
        'login[username]': email,
        'login[password]': password,
        'send': '',
      };

      if (formKey != null) {
        loginData['form_key'] = formKey;
      }

      // Submit login form
      final loginResponse = await _dio.post(
        loginUrl,
        data: loginData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: true,
        ),
      );

      // Check if login was successful by looking for account-specific content
      return await isLoggedIn();
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> isLoggedIn() async {
    await _initialize();

    try {
      final response = await _dio.get(accountUrl);
      final document = html_parser.parse(response.data);
      
      // Look for logout link or account-specific content
      final logoutLink = document.querySelector('a[href*="logout"]');
      final accountContent = document.querySelector('.customer-account-index');
      
      return logoutLink != null || accountContent != null;
    } catch (e) {
      print('Login check error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _initialize();

    try {
      // Clear cookies
      await _cookieJar.deleteAll();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  Future<List<Product>> getProducts() async {
    await _initialize();

    try {
      final response = await _dio.get(downloadsUrl);
      final document = html_parser.parse(response.data);
      
      return _parseProductsFromHtml(document);
    } catch (e) {
      print('Get products error: $e');
      throw Exception('Failed to fetch products: $e');
    }
  }

  List<Product> _parseProductsFromHtml(dom.Document document) {
    final products = <Product>[];
    
    // This is a simplified parser - you'll need to adjust based on actual JustFlight HTML structure
    final productElements = document.querySelectorAll('.product-item, .download-item, .downloadable-product');
    
    for (final element in productElements) {
      try {
        final product = _parseProductElement(element);
        if (product != null) {
          products.add(product);
        }
      } catch (e) {
        print('Error parsing product element: $e');
      }
    }
    
    // If no products found with the above selectors, try alternative parsing
    if (products.isEmpty) {
      products.addAll(_parseAlternativeProductStructure(document));
    }
    
    return products;
  }

  Product? _parseProductElement(dom.Element element) {
    // Extract product information - this will need to be customized based on actual HTML structure
    final nameElement = element.querySelector('.product-name, .title, h2, h3');
    final imageElement = element.querySelector('img');
    final descriptionElement = element.querySelector('.description, .product-description');
    final downloadLinks = element.querySelectorAll('a[href*="download"], a[href*=".zip"], a[href*=".exe"]');
    
    if (nameElement == null) return null;
    
    final name = nameElement.text.trim();
    final id = _generateProductId(name);
    final imageUrl = imageElement?.attributes['src'] ?? '';
    final description = descriptionElement?.text.trim() ?? '';
    
    // Parse download files
    final files = <ProductFile>[];
    for (int i = 0; i < downloadLinks.length; i++) {
      final link = downloadLinks[i];
      final fileName = link.text.trim().isNotEmpty ? link.text.trim() : 'Download ${i + 1}';
      final downloadUrl = link.attributes['href'] ?? '';
      
      if (downloadUrl.isNotEmpty) {
        files.add(ProductFile(
          id: '$id-file-$i',
          name: fileName,
          downloadUrl: downloadUrl.startsWith('http') ? downloadUrl : '$baseUrl$downloadUrl',
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
      purchaseDate: DateTime.now(), // Placeholder - would need to be parsed from actual data
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
          
          final downloadLink = linkCell.querySelector('a[href*="download"], a[href*=".zip"], a[href*=".exe"]');
          if (downloadLink != null) {
            final name = nameCell.text.trim();
            final id = _generateProductId(name);
            final downloadUrl = downloadLink.attributes['href'] ?? '';
            
            if (name.isNotEmpty && downloadUrl.isNotEmpty) {
              products.add(Product(
                id: id,
                name: name,
                description: '',
                imageUrl: '',
                category: 'Software',
                files: [
                  ProductFile(
                    id: '$id-file-0',
                    name: downloadLink.text.trim().isNotEmpty ? downloadLink.text.trim() : name,
                    downloadUrl: downloadUrl.startsWith('http') ? downloadUrl : '$baseUrl$downloadUrl',
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
    return name.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .trim();
  }

  String _extractCategory(String name, String description) {
    final text = '$name $description'.toLowerCase();
    
    if (text.contains('aircraft') || text.contains('plane')) return 'Aircraft';
    if (text.contains('airport') || text.contains('scenery')) return 'Scenery';
    if (text.contains('utility') || text.contains('tool')) return 'Utilities';
    if (text.contains('training') || text.contains('tutorial')) return 'Training';
    
    return 'Software';
  }

  String _extractFileType(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'unknown';
    
    final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    
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
      final downloadLink = document.querySelector('a[href*=".zip"], a[href*=".exe"], a[href*="download"]');
      if (downloadLink != null) {
        final href = downloadLink.attributes['href'];
        if (href != null) {
          return href.startsWith('http') ? href : '$baseUrl$href';
        }
      }

      return productFileUrl;
    } catch (e) {
      print('Get download URL error: $e');
      return productFileUrl;
    }
  }
}
