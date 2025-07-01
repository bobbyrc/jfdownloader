import 'dart:collection';
import 'dart:typed_data';
import '../models/product.dart';

/// In-memory cache service for improved performance
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();
  
  /// Initialize the cache service
  static Future<void> initialize() async {
    // Cache service initializes on first access
    CacheService(); // Create instance to trigger initialization
  }

  // Product image cache
  final _imageCache = LRUMap<String, Uint8List>(100); // Cache up to 100 images
  
  // Product data cache
  final _productCache = LRUMap<String, List<Product>>(10); // Cache product lists
  
  // URL cache for product pages
  final _urlCache = LRUMap<String, String>(200); // Cache product URLs
  
  // Cache expiry tracking
  final _cacheTimestamps = <String, DateTime>{};
  static const Duration _cacheExpiration = Duration(hours: 1);

  /// Cache product image data
  void cacheImage(String url, Uint8List data) {
    _imageCache[url] = data;
    _cacheTimestamps['image_$url'] = DateTime.now();
  }

  /// Get cached image data
  Uint8List? getCachedImage(String url) {
    final timestamp = _cacheTimestamps['image_$url'];
    if (timestamp != null && DateTime.now().difference(timestamp) > _cacheExpiration) {
      _imageCache.remove(url);
      _cacheTimestamps.remove('image_$url');
      return null;
    }
    return _imageCache[url];
  }

  /// Cache product list
  void cacheProducts(String key, List<Product> products) {
    _productCache[key] = List.from(products); // Defensive copy
    _cacheTimestamps['products_$key'] = DateTime.now();
  }

  /// Get cached product list
  List<Product>? getCachedProducts(String key) {
    final timestamp = _cacheTimestamps['products_$key'];
    if (timestamp != null && DateTime.now().difference(timestamp) > _cacheExpiration) {
      _productCache.remove(key);
      _cacheTimestamps.remove('products_$key');
      return null;
    }
    return _productCache[key];
  }

  /// Cache product page URL
  void cacheProductUrl(String productName, String url) {
    _urlCache[productName] = url;
    _cacheTimestamps['url_$productName'] = DateTime.now();
  }

  /// Get cached product URL
  String? getCachedProductUrl(String productName) {
    final timestamp = _cacheTimestamps['url_$productName'];
    if (timestamp != null && DateTime.now().difference(timestamp) > _cacheExpiration) {
      _urlCache.remove(productName);
      _cacheTimestamps.remove('url_$productName');
      return null;
    }
    return _urlCache[productName];
  }

  /// Clear expired entries
  void clearExpired() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiration) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cacheTimestamps.remove(key);
      if (key.startsWith('image_')) {
        _imageCache.remove(key.substring(6));
      } else if (key.startsWith('products_')) {
        _productCache.remove(key.substring(9));
      } else if (key.startsWith('url_')) {
        _urlCache.remove(key.substring(4));
      }
    }
  }

  /// Clear all cached data
  void clearAll() {
    _imageCache.clear();
    _productCache.clear();
    _urlCache.clear();
    _cacheTimestamps.clear();
  }

  /// Get cache statistics
  Map<String, int> getStats() {
    return {
      'images': _imageCache.length,
      'products': _productCache.length,
      'urls': _urlCache.length,
      'total_entries': _cacheTimestamps.length,
    };
  }
}

/// Simple LRU (Least Recently Used) cache implementation
class LRUMap<K, V> extends MapMixin<K, V> {
  final int _maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  LRUMap(this._maxSize);

  @override
  V? operator [](Object? key) {
    if (_cache.containsKey(key)) {
      // Move to end (most recently used)
      final value = _cache.remove(key);
      _cache[key as K] = value as V;
      return value;
    }
    return null;
  }

  @override
  void operator []=(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= _maxSize) {
      // Remove least recently used (first in LinkedHashMap)
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  @override
  void clear() => _cache.clear();

  @override
  Iterable<K> get keys => _cache.keys;

  @override
  V? remove(Object? key) => _cache.remove(key);

  int get length => _cache.length;
}
