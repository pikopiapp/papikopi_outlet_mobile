/// Helper to get product image path based on product name
/// Uses the product images from assets/products folder

class ProductImageHelper {
  // Map product names to their image filenames
  static const Map<String, String> productImageMap = {
    'baileys': 'Baileys.png',
    'butterscotch': 'Butterscotch.png',
    'cold brew': 'Cold Brew.png',
    'creme brulee': 'Creme Brulee.png',
    'gula aren': 'GulaAren.png',
    'gula arenmachiato': 'GulaAren.png',
    'hazelnut': 'Hazelnut.png',
    'vanilla': 'Vanilla.png',
  };

  // Base path for product images in assets
  static const String baseImagePath = 'assets/products';

  /// Get image asset path for a product by name
  /// Returns the image path if found, otherwise null
  static String? getProductImagePath(String? productName) {
    if (productName == null || productName.isEmpty) {
      return null;
    }

    // Normalize product name: lowercase and trim
    final normalizedName = productName.toLowerCase().trim();

    // Try exact match first
    for (var entry in productImageMap.entries) {
      if (normalizedName == entry.key) {
        return '$baseImagePath/${entry.value}';
      }
    }

    // Try partial match (product name contains key or key contains product name)
    for (var entry in productImageMap.entries) {
      if (normalizedName.contains(entry.key) || entry.key.contains(normalizedName)) {
        return '$baseImagePath/${entry.value}';
      }
    }

    return null;
  }

  /// Get filename for a product by name (without base path)
  static String? getProductImageFilename(String? productName) {
    if (productName == null || productName.isEmpty) {
      return null;
    }

    final normalizedName = productName.toLowerCase().trim();

    for (var entry in productImageMap.entries) {
      if (normalizedName == entry.key) {
        return entry.value;
      }
    }

    for (var entry in productImageMap.entries) {
      if (normalizedName.contains(entry.key) || entry.key.contains(normalizedName)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Get all available product images
  static List<String> getAllProductImages() {
    return productImageMap.values.toList();
  }

  /// Check if product has an image
  static bool hasProductImage(String? productName) {
    return getProductImagePath(productName) != null;
  }
}
