import 'package:flutter_test/flutter_test.dart';
import 'package:bookstore/features/auth/services/auth_api_service.dart';

void main() {
  group('Auth API Service Tests', () {
    test('should return login response when using API', () async {
      // This test verifies that the API response works
      final response = await AuthApiService.login(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(response.success, isTrue);
      expect(response.message, isNotNull);
    });

    test('should return register response when using API', () async {
      // This test verifies that the API response works
      final response = await AuthApiService.register(
        email: 'newuser@example.com',
        password: 'password123',
        firstName: 'New',
        lastName: 'User',
        userType: 'customer',
      );

      expect(response.success, isTrue);
      expect(response.message, isNotNull);
    });

    test('should return profile response when using API', () async {
      // This test verifies that the API response works
      final response = await AuthApiService.getProfile('mock_token');

      expect(response.success, isTrue);
      expect(response.message, isNotNull);
    });
  });
}
