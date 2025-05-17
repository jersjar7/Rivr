// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/register.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/update_user_profile.dart';
import '../../data/datasources/auth_storage_service.dart';
import '../../../../core/error/firebase_error_mapper.dart';
import '../../data/datasources/biometric_auth_service.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

class AuthProvider with ChangeNotifier {
  final Login _login;
  final Register _register;
  final GetCurrentUser _getCurrentUser;
  final SendPasswordResetEmail _sendPasswordResetEmail;
  final SignOut _signOut;
  final AuthStorageService _authStorage;
  final UpdateUserProfile _updateUserProfile;
  final BiometricAuthService _biometricAuthService;

  User? _currentUser;
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  bool _isInitialized = false;

  AuthProvider({
    required Login login,
    required Register register,
    required GetCurrentUser getCurrentUser,
    required SendPasswordResetEmail sendPasswordResetEmail,
    required SignOut signOut,
    required AuthStorageService authStorage,
    required UpdateUserProfile updateUserProfile,
    required BiometricAuthService biometricAuthService,
  }) : _login = login,
       _register = register,
       _getCurrentUser = getCurrentUser,
       _sendPasswordResetEmail = sendPasswordResetEmail,
       _signOut = signOut,
       _authStorage = authStorage,
       _updateUserProfile = updateUserProfile,
       _biometricAuthService = biometricAuthService {
    // Initialize the field
    // Initialize provider
    _initialize();
  }

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;
  // getters for biometric auth
  Future<bool> get isBiometricAvailable =>
      _biometricAuthService.isBiometricAvailable();
  Future<bool> get isBiometricEnabled =>
      _biometricAuthService.isBiometricEnabled();

  /// Initialize authentication state
  Future<void> _initialize() async {
    await refreshCurrentUser();
    _isInitialized = true;
    notifyListeners();
  }

  /// Refresh current user data from repository
  Future<void> refreshCurrentUser() async {
    print("AUTH PROVIDER: refreshCurrentUser called");
    // First check secure storage for stored auth data
    final hasStoredAuth = await _authStorage.hasAuthData();
    print("AUTH PROVIDER: hasStoredAuth=$hasStoredAuth");

    if (!hasStoredAuth) {
      print("AUTH PROVIDER: No stored auth, setting user to null");
      _currentUser = null;
      notifyListeners();
      return;
    }

    print("AUTH PROVIDER: Stored auth found, checking with repository");

    // Add timeout protection
    try {
      // Use a timeout to prevent getting stuck
      final result = await _getCurrentUser().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print("AUTH PROVIDER: Repository call timed out");
          // Return a failure on timeout
          return Left(AuthFailure(message: 'Repository check timed out'));
        },
      );

      print("AUTH PROVIDER: Repository returned a result");

      result.fold(
        (failure) {
          print(
            "AUTH PROVIDER: Failed to get current user: ${failure.message}",
          );
          _currentUser = null;
          // Clear invalid auth data if we get a failure
          _authStorage.clearAuthData();
        },
        (user) {
          print("AUTH PROVIDER: Got user from repository: ${user?.uid}");
          _currentUser = user;
        },
      );
    } catch (e) {
      print("AUTH PROVIDER: Exception during repository check: $e");
      _currentUser = null;
      await _authStorage.clearAuthData();
    }

    notifyListeners();
    print("AUTH PROVIDER: refreshCurrentUser completed");
  }

  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();
  }

  // Add methods for biometric auth
  Future<bool> enableBiometric() async {
    print("AUTH PROVIDER: Enabling biometric authentication");
    if (_currentUser == null) {
      print("AUTH PROVIDER: No current user, can't enable biometrics");
      return false;
    }

    try {
      final result = await _biometricAuthService
          .enableBiometric(_currentUser!.uid, _currentUser!.email)
          .timeout(
            const Duration(seconds: 30), // Biometric setup can take time
            onTimeout: () {
              print("AUTH PROVIDER: Biometric setup timed out");
              return false;
            },
          );

      print("AUTH PROVIDER: Biometric setup result: $result");
      return result;
    } catch (e) {
      print("AUTH PROVIDER: Error enabling biometrics: $e");
      return false;
    }
  }

  Future<void> disableBiometric() async {
    await _biometricAuthService.disableBiometric();
  }

  // Add biometric login method
  Future<User?> loginWithBiometric() async {
    if (!await _biometricAuthService.isBiometricAvailable()) {
      _errorMessage = 'Biometric authentication not available on this device';
      notifyListeners();
      return null;
    }

    if (!await _biometricAuthService.isBiometricEnabled()) {
      _errorMessage =
          'Biometric login not enabled. Please enable it in settings.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final authenticated = await _biometricAuthService.authenticate(
        'Login to Rivr using biometric authentication',
      );

      if (!authenticated) {
        _isLoading = false;
        _errorMessage = 'Biometric authentication failed';
        notifyListeners();
        return null;
      }

      // Get stored credentials
      final credentials = await _biometricAuthService.getBiometricCredentials();
      if (credentials == null) {
        _isLoading = false;
        _errorMessage =
            'No biometric credentials found. Please set up biometric login again.';
        notifyListeners();
        return null;
      }

      // Get user with the stored userId
      final result = await _getCurrentUser();

      return result.fold(
        (failure) {
          _isLoading = false;
          _errorMessage = 'Failed to get user account: ${failure.message}';
          notifyListeners();
          return null;
        },
        (user) async {
          if (user == null) {
            _isLoading = false;
            _errorMessage = 'User account not found';
            notifyListeners();
            return null;
          }

          _currentUser = user;
          _isLoading = false;
          _successMessage = 'Login successful';
          notifyListeners();
          return user;
        },
      );
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Biometric authentication error: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  Future<User?> login(String email, String password) async {
    print("AUTH PROVIDER: login started");
    if (email.isEmpty || password.isEmpty) {
      print("AUTH PROVIDER: Empty fields detected");
      _errorMessage = 'Please fill in all fields';
      notifyListeners();
      return null;
    }

    print("AUTH PROVIDER: Setting loading state");
    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    print("AUTH PROVIDER: Calling _login use case");
    try {
      final result = await _login(email, password);
      print("AUTH PROVIDER: _login use case returned a result");

      return result.fold(
        (failure) {
          print("AUTH PROVIDER: login failure: ${failure.message}");
          _isLoading = false;
          _errorMessage = failure.message;

          // Add recovery suggestions for common auth errors
          if (failure.message.contains('password')) {
            _errorMessage +=
                '\n${FirebaseErrorMapper.getRecoverySuggestion('wrong-password') ?? ''}';
          } else if (failure.message.contains('No account found')) {
            _errorMessage +=
                '\n${FirebaseErrorMapper.getRecoverySuggestion('user-not-found') ?? ''}';
          }

          notifyListeners();
          return null;
        },
        (user) async {
          print("AUTH PROVIDER: login success, got user with id: ${user.uid}");
          _currentUser = user;
          _isLoading = false;

          // Save auth data to secure storage
          print("AUTH PROVIDER: Saving auth data to storage");
          try {
            await _authStorage.saveAuthData(
              userId: user.uid,
              email: user.email,
            );
            print("AUTH PROVIDER: Auth data saved successfully");
          } catch (e) {
            print("AUTH PROVIDER: Error saving auth data: $e");
          }

          _successMessage = 'Login successful';
          notifyListeners();
          print("AUTH PROVIDER: login method completed successfully");
          return user;
        },
      );
    } catch (e) {
      print("AUTH PROVIDER: Unexpected error in login: $e");
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred: $e';
      notifyListeners();
      return null;
    }
  }

  Future<User?> register(
    String email,
    String password,
    String firstName,
    String lastName,
    String profession,
  ) async {
    print("AUTH PROVIDER: register started");
    if (email.isEmpty ||
        password.isEmpty ||
        firstName.isEmpty ||
        lastName.isEmpty) {
      print("AUTH PROVIDER: Empty required fields detected");
      _errorMessage = 'Please fill in all required fields';
      notifyListeners();
      return null;
    }

    print("AUTH PROVIDER: Setting loading state");
    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    print("AUTH PROVIDER: Calling _register use case");
    try {
      // Add timeout to prevent hanging
      final result = await _register(
        email,
        password,
        firstName,
        lastName,
        profession,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print("AUTH PROVIDER: register use case timed out");
          return Left(AuthFailure(message: 'Registration timed out'));
        },
      );

      print("AUTH PROVIDER: _register use case returned a result");

      return result.fold(
        (failure) {
          print("AUTH PROVIDER: register failure: ${failure.message}");
          _isLoading = false;
          _errorMessage = failure.message;
          notifyListeners();
          return null;
        },
        (user) async {
          print(
            "AUTH PROVIDER: register success, got user with id: ${user.uid}",
          );
          _currentUser = user;
          _isLoading = false;

          // Save auth data to secure storage
          print("AUTH PROVIDER: Saving auth data to storage");
          try {
            await _authStorage.saveAuthData(
              userId: user.uid,
              email: user.email,
            );
            print("AUTH PROVIDER: Auth data saved successfully");
          } catch (e) {
            print("AUTH PROVIDER: Error saving auth data: $e");
          }

          _successMessage = 'Registration successful';
          notifyListeners();
          print("AUTH PROVIDER: register method completed successfully");
          return user;
        },
      );
    } catch (e) {
      print("AUTH PROVIDER: Unexpected error in register: $e");
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    print("AUTH PROVIDER: Attempting to send password reset email");
    if (email.isEmpty) {
      print("AUTH PROVIDER: Email is empty");
      _errorMessage = 'Please enter your email';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final result = await _sendPasswordResetEmail(email).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print("AUTH PROVIDER: Password reset email request timed out");
          return Left(
            AuthFailure(message: 'Request timed out. Please try again later.'),
          );
        },
      );

      return result.fold(
        (failure) {
          print(
            "AUTH PROVIDER: Password reset email failure: ${failure.message}",
          );
          _isLoading = false;
          _errorMessage = failure.message;
          notifyListeners();
          return false;
        },
        (_) {
          print("AUTH PROVIDER: Password reset email sent successfully");
          _isLoading = false;
          _successMessage = 'Password reset link sent to your email';
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      print("AUTH PROVIDER: Unexpected error sending password reset email: $e");
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    print("AUTH PROVIDER: Logout initiated");
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _signOut().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print("AUTH PROVIDER: Logout timed out, treating as success");
          return const Right(null); // Treat timeout as success
        },
      );

      result.fold(
        (failure) {
          print("AUTH PROVIDER: Logout failure: ${failure.message}");
          _isLoading = false;
          _errorMessage = failure.message;
          notifyListeners();
        },
        (_) async {
          print("AUTH PROVIDER: Logout successful, clearing local data");
          _currentUser = null;
          _isLoading = false;

          // Clear auth data from secure storage
          try {
            await _authStorage.clearAuthData();
            print("AUTH PROVIDER: Auth data cleared successfully");
          } catch (e) {
            print("AUTH PROVIDER: Error clearing auth data: $e");
          }

          notifyListeners();
          print("AUTH PROVIDER: Logout process completed");
        },
      );
    } catch (e) {
      print("AUTH PROVIDER: Unexpected error during logout: $e");
      // Even on error, still clear local data for better UX
      _currentUser = null;
      _isLoading = false;
      try {
        await _authStorage.clearAuthData();
      } catch (_) {}
      notifyListeners();
    }
  }

  /// Check if the stored session is still valid
  Future<bool> validateSession() async {
    print("AUTH PROVIDER: Validating session");
    if (_currentUser == null) {
      print("AUTH PROVIDER: No current user, session invalid");
      return false;
    }

    try {
      // Check last login time to enforce session timeout if needed
      final lastLogin = await _authStorage.getLastLogin().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print("AUTH PROVIDER: getLastLogin timed out");
          return null; // If we can't get last login, assume session is valid
        },
      );

      if (lastLogin != null) {
        final sessionAge = DateTime.now().difference(lastLogin);
        print("AUTH PROVIDER: Session age: ${sessionAge.inDays} days");

        // If last login was more than 30 days ago, invalidate session
        if (sessionAge.inDays > 30) {
          print("AUTH PROVIDER: Session expired (> 30 days), logging out");
          await logout();
          return false;
        }
      }

      print("AUTH PROVIDER: Session valid");
      return true;
    } catch (e) {
      print("AUTH PROVIDER: Error validating session: $e");
      // On any error, assume session is valid for better UX
      return true;
    }
  }

  /// Update user profile information
  Future<bool> updateUserProfile({
    String? firstName,
    String? lastName,
    String? profession,
  }) async {
    if (_currentUser == null) {
      _errorMessage = 'You must be logged in to update your profile';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    // Use the injected UpdateUserProfile use case
    final result = await _updateUserProfile(
      _currentUser!.uid,
      firstName: firstName,
      lastName: lastName,
      profession: profession,
    );

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (updatedUser) {
        _currentUser = updatedUser;
        _isLoading = false;
        _successMessage = 'Profile updated successfully';
        notifyListeners();
        return true;
      },
    );
  }

  /// Force refresh the user profile data from server
  Future<bool> refreshUserProfile() async {
    if (_currentUser == null) {
      return false;
    }

    _isLoading = true;
    notifyListeners();

    final result = await _getCurrentUser();

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (user) {
        _isLoading = false;
        if (user != null) {
          _currentUser = user;
          notifyListeners();
          return true;
        }
        return false;
      },
    );
  }
}
