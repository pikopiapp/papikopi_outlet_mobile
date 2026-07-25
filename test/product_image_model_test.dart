import 'package:flutter_test/flutter_test.dart';
import 'package:papikopi/models/product.dart';

void main() {
  group('Product image parsing', () {
    test('uses image field when image_url is missing', () {
      final product = Product.fromJson({
        'id': 'prod-1',
        'category_id': 'cat-1',
        'name': 'Latte',
        'description': 'Test',
        'price': 25000,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'image': 'https://example.com/products/latte.png',
      });

      expect(product.imageUrl, 'https://example.com/products/latte.png');
    });

    test('trims whitespace from image URLs before loading', () {
      final product = Product.fromJson({
        'id': 'prod-2',
        'category_id': 'cat-1',
        'name': 'Americano',
        'description': 'Test',
        'price': 20000,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'image_url': '  https://example.com/products/americano.png  ',
      });

      expect(product.imageUrl, 'https://example.com/products/americano.png');
    });

    test('ignores malformed image URLs that cannot be loaded', () {
      final product = Product.fromJson({
        'id': 'prod-3',
        'category_id': 'cat-1',
        'name': 'Mocha',
        'description': 'Test',
        'price': 22000,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'image_url': 'not-a-valid-url',
      });

      expect(product.imageUrl, isNull);
    });
  });
}
