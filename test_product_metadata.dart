import 'dart:io';
import 'lib/services/justflight_service.dart';

void main() async {
  print('Testing product details metadata...');
  
  // Read credentials from environment
  final email = Platform.environment['JUSTFLIGHT_EMAIL'] ?? 'test@example.com';
  final password = Platform.environment['JUSTFLIGHT_PASSWORD'] ?? 'password';
  
  final service = JustFlightService();
  
  try {
    print('Logging in...');
    final loginSuccess = await service.login(email, password);
    if (!loginSuccess) {
      print('❌ Login failed');
      return;
    }
    print('✅ Login successful');
    
    print('\nFetching products...');
    final products = await service.getProducts();
    print('✅ Found ${products.length} products');
    
    if (products.isNotEmpty) {
      final firstProduct = products.first;
      print('\nTesting product details for: ${firstProduct.name} (ID: ${firstProduct.id})');
      
      final productDetails = await service.getProductDetails(firstProduct.id);
      
      print('\n=== METADATA TEST RESULTS ===');
      print('Order Number: ${productDetails['orderNumber']}');
      print('Purchase Date: ${productDetails['purchaseDate']}');
      print('Version: ${productDetails['version']}');
      print('Files: ${(productDetails['files'] as List?)?.length ?? 0}');
      print('Installation Info: ${(productDetails['installationInfo'] as Map?)?.length ?? 0}');
      print('============================');
      
      // Check types
      print('\n=== TYPE CHECK ===');
      print('orderNumber type: ${productDetails['orderNumber'].runtimeType}');
      print('purchaseDate type: ${productDetails['purchaseDate'].runtimeType}');
      print('version type: ${productDetails['version'].runtimeType}');
      print('==================');
      
    } else {
      print('❌ No products found');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
