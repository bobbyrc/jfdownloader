// Test simulating the exact flow from service to UI
void main() {
  print('=== SIMULATING SERVICE TO UI FLOW ===');
  
  // Simulate what the service returns (based on your debug output)
  final Map<String, dynamic> serviceResult = {
    'product': null, // Product object would be here
    'files': [], // List of ProductFile objects
    'installationInfo': {}, // Map of installation info
    'orderNumber': 'JFL2220374062C8F9A7', // This should be extracted
    'purchaseDate': DateTime(2023, 3, 15), // This should be extracted  
    'version': '0.4.3', // This should be extracted from file names
  };
  
  print('Service returned:');
  print('  orderNumber: ${serviceResult['orderNumber']}');
  print('  purchaseDate: ${serviceResult['purchaseDate']}');
  print('  version: ${serviceResult['version']}');
  
  // Simulate what happens in the UI (ProductDetailsScreen)
  String? _orderNumber = serviceResult['orderNumber'] as String?;
  DateTime? _purchaseDate = serviceResult['purchaseDate'] as DateTime?;
  String? _version = serviceResult['version'] as String?;
  
  print('\nUI State Variables:');
  print('  _orderNumber: $_orderNumber');
  print('  _purchaseDate: $_purchaseDate');
  print('  _version: $_version');
  
  // Simulate what should be displayed in the UI
  final productId = 'JFL2220374062C8F9A7'; // Fallback from product
  final productPurchaseDate = DateTime(2022, 1, 1); // Fallback from product
  final productVersion = '1.0'; // Fallback from product
  
  print('\nWhat UI would show:');
  print('  Order: ${_orderNumber ?? productId}');
  print('  Purchased: ${_formatDate(_purchaseDate ?? productPurchaseDate)}');
  print('  Version: ${_version ?? productVersion}');
  
  // Test if the extracted values would override the fallbacks
  if (_orderNumber != null && _orderNumber != productId) {
    print('✅ Order number would be overridden with extracted value');
  } else {
    print('❌ Order number would use fallback value');
  }
  
  if (_purchaseDate != null && _purchaseDate != productPurchaseDate) {
    print('✅ Purchase date would be overridden with extracted value');
  } else {
    print('❌ Purchase date would use fallback value');
  }
  
  if (_version != null && _version != productVersion) {
    print('✅ Version would be overridden with extracted value');
  } else {
    print('❌ Version would use fallback value');
  }
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}
