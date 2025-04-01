// lib/features/auth/data/datasources/auth_storage_service.dart
import '../../../../core/storage/secure_storage.dart';

/// Service responsible for managing authentication state in secure storage
class AuthStorageService {
  final SecureStorage _secureStorage;

  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _lastLoginKey = 'last_login';

  AuthStorageService({required SecureStorage secureStorage})
    : _secureStorage = secureStorage;

  /// Saves the user authentication data to secure storage
  Future<void> saveAuthData({
    required String userId,
    required String email,
  }) async {
    await _secureStorage.write(_userIdKey, userId);
    await _secureStorage.write(_userEmailKey, email);
    await _secureStorage.write(_lastLoginKey, DateTime.now().toIso8601String());
  }

  /// Retrieves the user ID from secure storage
  Future<String?> getUserId() async {
    return await _secureStorage.read(_userIdKey);
  }

  /// Retrieves the user email from secure storage
  Future<String?> getUserEmail() async {
    return await _secureStorage.read(_userEmailKey);
  }

  /// Retrieves the last login timestamp from secure storage
  Future<DateTime?> getLastLogin() async {
    final timestamp = await _secureStorage.read(_lastLoginKey);
    if (timestamp != null) {
      try {
        return DateTime.parse(timestamp);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Checks if there is authentication data stored
  Future<bool> hasAuthData() async {
    final userId = await getUserId();
    return userId != null && userId.isNotEmpty;
  }

  /// Clears all authentication data from secure storage
  Future<void> clearAuthData() async {
    await _secureStorage.delete(_userIdKey);
    await _secureStorage.delete(_userEmailKey);
    await _secureStorage.delete(_lastLoginKey);
  }
}
