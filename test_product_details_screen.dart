import 'package:flutter/material.dart';
import 'lib/models/product.dart';
import 'lib/screens/product_details_screen.dart';

void main() {
  print('=== Testing Product Details Screen ===');
  
  // Create a test product
  final testProduct = Product(
    id: 'test-product-1',
    name: 'Test Flight Simulator Add-on',
    description: 'A test product for demonstrating the product details screen functionality.',
    imageUrl: 'https://example.com/image.jpg',
    category: 'Flight Simulator',
    files: [
      ProductFile(
        id: 'test-file-1',
        name: 'installer.exe',
        downloadUrl: 'https://example.com/download/installer.exe',
        fileType: 'exe',
        sizeInMB: 150.5,
      ),
      ProductFile(
        id: 'test-file-2',
        name: 'manual.pdf',
        downloadUrl: 'https://example.com/download/manual.pdf',
        fileType: 'pdf',
        sizeInMB: 5.2,
      ),
    ],
    purchaseDate: DateTime(2024, 6, 15),
    version: '2.1.0',
    sizeInMB: 155.7,
  );
  
  print('Test product created:');
  print('  ID: ${testProduct.id}');
  print('  Name: ${testProduct.name}');
  print('  Files: ${testProduct.files.length}');
  
  // Test that the ProductDetailsScreen can be instantiated
  try {
    final screen = ProductDetailsScreen(product: testProduct);
    print('✓ ProductDetailsScreen instantiated successfully');
    print('  Product name: ${screen.product.name}');
  } catch (e) {
    print('✗ Error instantiating ProductDetailsScreen: $e');
  }
  
  print('\n=== Test completed ===');
}
