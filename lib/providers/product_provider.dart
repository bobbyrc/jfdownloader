import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/justflight_service.dart';

class ProductProvider extends ChangeNotifier {
  final JustFlightService _justFlightService = JustFlightService();
  
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  
  // Progress tracking for image fetching
  bool _isFetchingImages = false;
  int _totalProducts = 0;
  int _completedProducts = 0;
  String _currentProgressMessage = '';
  
  List<Product> get products => _filteredProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  
  // Progress getters
  bool get isFetchingImages => _isFetchingImages;
  double get imageProgress => _totalProducts > 0 ? _completedProducts / _totalProducts : 0.0;
  String get progressMessage => _currentProgressMessage;
  int get completedProducts => _completedProducts;
  int get totalProducts => _totalProducts;
  
  List<String> get categories {
    final cats = _products.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  List<Product> get _filteredProducts {
    var filtered = _products;
    
    if (_selectedCategory != 'All') {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) => 
        p.name.toLowerCase().contains(query) ||
        p.description.toLowerCase().contains(query) ||
        p.category.toLowerCase().contains(query)
      ).toList();
    }
    
    return filtered;
  }

  Future<void> loadProducts({bool fetchImages = true}) async {
    _setLoading(true);
    _clearError();

    try {
      _products = await _justFlightService.getProducts(
        fetchImages: fetchImages,
        onProgressUpdate: fetchImages ? (completed, total, message) {
          if (completed == 0) {
            // Products are loaded, now starting image fetching
            _setLoading(false);
            _startImageFetching(total);
          } else if (completed < total) {
            _updateImageProgress(completed, total, message);
          } else {
            _finishImageFetching();
          }
        } : null,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to load products: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshProducts({bool fetchImages = true}) async {
    await loadProducts(fetchImages: fetchImages);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void updateProductDownloadStatus(String productId, bool isDownloaded, String? localPath) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(
        isDownloaded: isDownloaded,
        localPath: localPath,
      );
      notifyListeners();
    }
  }

  Product? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  // Progress tracking methods
  void _setImageFetchingProgress(bool fetching, int total, int completed, String message) {
    _isFetchingImages = fetching;
    _totalProducts = total;
    _completedProducts = completed;
    _currentProgressMessage = message;
    notifyListeners();
  }

  void _startImageFetching(int total) {
    _setImageFetchingProgress(true, total, 0, 'Starting image fetching...');
  }

  void _updateImageProgress(int completed, int total, String message) {
    _setImageFetchingProgress(true, total, completed, message);
  }

  void _finishImageFetching() {
    _setImageFetchingProgress(false, _totalProducts, _totalProducts, 'Image fetching complete!');
  }
}
