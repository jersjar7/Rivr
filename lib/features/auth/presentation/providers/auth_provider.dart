// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/register.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/update_user_profile.dart'; // Add this import
import '../../data/datasources/auth_storage_service.dart';
import '../../../../core/error/firebase_error_mapper.dart';

class AuthProvider with ChangeNotifier {
  final Login _login;
  final Register _register;
  final GetCurrentUser _getCurrentUser;
  final SendPasswordResetEmail _sendPasswordResetEmail;
  final SignOut _signOut;
  final AuthStorageService _authStorage;
  final UpdateUserProfile _updateUserProfile; // Add this field

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
    required UpdateUserProfile updateUserProfile, // Add this parameter
  }) : _login = login,
       _register = register,
       _getCurrentUser = getCurrentUser,
       _sendPasswordResetEmail = sendPasswordResetEmail,
       _signOut = signOut,
       _authStorage = authStorage,
       _updateUserProfile = updateUserProfile {
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

  /// Initialize authentication state
  Future<void> _initialize() async {
    await refreshCurrentUser();
    _isInitialized = true;
    notifyListeners();
  }

  /// Refresh current user data from repository
  Future<void> refreshCurrentUser() async {
    // First check secure storage for stored auth data
    final hasStoredAuth = await _authStorage.hasAuthData();

    if (!hasStoredAuth) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    // If auth data exists, verify with repository
    final result = await _getCurrentUser();
    result.fold((failure) {
      _currentUser = null;
      // Clear invalid auth data if we get a failure
      _authStorage.clearAuthData();
    }, (user) => _currentUser = user);

    notifyListeners();
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

  Future<User?> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      _errorMessage = 'Please fill in all fields';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    final result = await _login(email, password);

    return result.fold(
      (failure) {
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
        _currentUser = user;
        _isLoading = false;

        // Save auth data to secure storage
        await _authStorage.saveAuthData(userId: user.id, email: user.email);

        _successMessage = 'Login successful';
        notifyListeners();
        return user;
      },
    );
  }

  Future<User?> register(
    String email,
    String password,
    String firstName,
    String lastName,
    String profession,
  ) async {
    if (email.isEmpty ||
        password.isEmpty ||
        firstName.isEmpty ||
        lastName.isEmpty) {
      _errorMessage = 'Please fill in all required fields';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    final result = await _register(
      email,
      password,
      firstName,
      lastName,
      profession,
    );

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return null;
      },
      (user) async {
        _currentUser = user;
        _isLoading = false;

        // Save auth data to secure storage
        await _authStorage.saveAuthData(userId: user.id, email: user.email);

        _successMessage = 'Registration successful';
        notifyListeners();
        return user;
      },
    );
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    if (email.isEmpty) {
      _errorMessage = 'Please enter your email';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    final result = await _sendPasswordResetEmail(email);

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        _isLoading = false;
        _successMessage = 'Password reset link sent to your email';
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    final result = await _signOut();

    result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (_) async {
        _currentUser = null;
        _isLoading = false;

        // Clear auth data from secure storage
        await _authStorage.clearAuthData();

        notifyListeners();
      },
    );
  }

  /// Check if the stored session is still valid
  Future<bool> validateSession() async {
    if (_currentUser == null) {
      return false;
    }

    // Check last login time to enforce session timeout if needed
    final lastLogin = await _authStorage.getLastLogin();
    if (lastLogin != null) {
      final sessionAge = DateTime.now().difference(lastLogin);
      // If last login was more than 30 days ago, invalidate session
      if (sessionAge.inDays > 30) {
        await logout();
        return false;
      }
    }

    return true;
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
      _currentUser!.id,
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
