import 'package:flutter/foundation.dart';
import '../services/justflight_service.dart';

class AuthProvider extends ChangeNotifier {
  final JustFlightService _justFlightService = JustFlightService();
  
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  String? _username;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get username => _username;

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // For debugging - call debug method on first attempt
      if (!_isLoggedIn) {
        await _justFlightService.debugLoginPage();
      }
      
      final success = await _justFlightService.login(email, password);
      if (success) {
        _isLoggedIn = true;
        _username = email;
        notifyListeners();
        return true;
      } else {
        _setError('Login failed. Please check your credentials and try again.\n\nIf this continues, the website structure may have changed.\nCheck the console for detailed debug information.');
        return false;
      }
    } catch (e) {
      _setError('Login failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    
    try {
      await _justFlightService.logout();
      _isLoggedIn = false;
      _username = null;
      notifyListeners();
    } catch (e) {
      _setError('Logout failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> checkLoginStatus() async {
    _setLoading(true);

    try {
      final isValid = await _justFlightService.isLoggedIn();
      _isLoggedIn = isValid;
      notifyListeners();
      return isValid;
    } catch (e) {
      _setError('Failed to check login status: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
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
