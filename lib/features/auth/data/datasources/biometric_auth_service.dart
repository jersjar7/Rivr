// lib/features/auth/data/datasources/biometric_auth_service.dart
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import '../../../../core/storage/secure_storage.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorage _secureStorage;

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricUserIdKey = 'biometric_user_id';
  static const String _biometricEmailKey = 'biometric_email';

  BiometricAuthService({required SecureStorage secureStorage})
    : _secureStorage = secureStorage;

  // Check if device supports biometric auth
  Future<bool> isBiometricAvailable() async {
    final canCheckBiometrics = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    return canCheckBiometrics && isDeviceSupported;
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    return await _localAuth.getAvailableBiometrics();
  }

  // Check if user has enabled biometric login
  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.read(_biometricEnabledKey);
    return value == 'true';
  }

  // Enable biometric login for a user
  Future<bool> enableBiometric(String userId, String email) async {
    try {
      final authenticated = await authenticate(
        'Authenticate to enable biometric login',
      );
      if (authenticated) {
        await _secureStorage.write(_biometricEnabledKey, 'true');
        await _secureStorage.write(_biometricUserIdKey, userId);
        await _secureStorage.write(_biometricEmailKey, email);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Disable biometric login
  Future<void> disableBiometric() async {
    await _secureStorage.delete(_biometricEnabledKey);
    await _secureStorage.delete(_biometricUserIdKey);
    await _secureStorage.delete(_biometricEmailKey);
  }

  // Authenticate using biometrics
  Future<bool> authenticate(String reason) async {
    print("BIOMETRIC: Starting authentication with reason: $reason");
    try {
      final result = await _localAuth
          .authenticate(
            localizedReason: reason,
            options: const AuthenticationOptions(stickyAuth: true),
          )
          .timeout(
            const Duration(
              seconds: 30,
            ), // Biometric auth can take time for user interaction
            onTimeout: () {
              print("BIOMETRIC: Authentication timed out");
              return false;
            },
          );

      print("BIOMETRIC: Authentication result: $result");
      return result;
    } catch (e) {
      print("BIOMETRIC: Authentication error: $e");
      if (e is PlatformException) {
        if (e.code == auth_error.notAvailable) {
          print('BIOMETRIC: Biometric not available');
        } else if (e.code == auth_error.notEnrolled) {
          print('BIOMETRIC: Biometric not enrolled');
        }
      }
      return false;
    }
  }

  // Get stored credentials for biometric login
  Future<Map<String, String>?> getBiometricCredentials() async {
    if (await isBiometricEnabled()) {
      final userId = await _secureStorage.read(_biometricUserIdKey);
      final email = await _secureStorage.read(_biometricEmailKey);

      if (userId != null && email != null) {
        return {'userId': userId, 'email': email};
      }
    }
    return null;
  }
}
