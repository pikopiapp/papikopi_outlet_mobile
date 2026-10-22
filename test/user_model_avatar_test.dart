import 'package:flutter_test/flutter_test.dart';
import 'package:papikopi/models/user.dart';

void main() {
  test('parses avatar url from user payload', () {
    final user = User.fromJson({
      'id': 'user-1',
      'email': 'user@example.com',
      'name': 'Test User',
      'role': 'barista',
      'outlet_id': 'outlet-1',
      'avatar_url': 'https://example.com/avatar.png',
      'created_at': '2024-01-01T00:00:00.000Z',
    });

    expect(user.avatarUrl, 'https://example.com/avatar.png');
  });

  test('parses and serializes inactive user status', () {
    final user = User.fromJson({
      'id': 'user-1',
      'email': 'user@example.com',
      'name': 'Test User',
      'role': 'barista',
      'outlet_id': 'outlet-1',
      'is_active': false,
      'created_at': '2024-01-01T00:00:00.000Z',
    });

    expect(user.isActive, isFalse);
    expect(user.toJson()['is_active'], isFalse);
  });
}
