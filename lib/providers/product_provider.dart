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
  
  List<Product> get products => _filteredProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  
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

  Future<void> loadProducts() async {
    _setLoading(true);
    _clearError();

    try {
      _products = await _justFlightService.getProducts();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load products: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshProducts() async {
    await loadProducts();
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
}
