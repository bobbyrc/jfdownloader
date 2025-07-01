// Quick test for URL generation
void main() {
  String generateProductUrl(String productName) {
    // Convert product name to URL slug
    String slug = productName
        .toLowerCase()
        // Remove version numbers and simulator tags before processing
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '') // Remove anything in parentheses like (MSFS), (X-Plane 12), etc.
        // Handle specific character replacements
        .replaceAll('&', ' and ') // Replace ampersand with ' and '
        .replaceAll('/', '-') // Replace forward slash with hyphen
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove remaining special characters except spaces and hyphens
        .replaceAll(RegExp(r'\s+'), '-') // Replace spaces with hyphens
        .replaceAll(RegExp(r'-+'), '-') // Replace multiple hyphens with single hyphen
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

  // Test case
  final testCase = 'PA-28R Arrow III & Turbo Arrow III/IV Bundle (MSFS)';
  final url = generateProductUrl(testCase);
  print('Input: $testCase');
  print('Generated: $url');
  print('Expected:  https://www.justflight.com/product/pa28r-arrow-iii-and-turbo-arrow-iii-iv-bundle-microsoft-flight-simulator');
}
