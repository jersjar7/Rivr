// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/register.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../../domain/usecases/sign_out.dart';
import '../../../../core/storage/secure_storage.dart';

class AuthProvider with ChangeNotifier {
  final Login _login;
  final Register _register;
  final GetCurrentUser _getCurrentUser;
  final SendPasswordResetEmail _sendPasswordResetEmail;
  final SignOut _signOut;
  final SecureStorage _secureStorage;

  User? _currentUser;
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';

  AuthProvider({
    required Login login,
    required Register register,
    required GetCurrentUser getCurrentUser,
    required SendPasswordResetEmail sendPasswordResetEmail,
    required SignOut signOut,
    required SecureStorage secureStorage,
  }) : _login = login,
       _register = register,
       _getCurrentUser = getCurrentUser,
       _sendPasswordResetEmail = sendPasswordResetEmail,
       _signOut = signOut,
       _secureStorage = secureStorage {
    // Check if user is logged in on initialization
    _checkCurrentUser();
  }

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  bool get isAuthenticated => _currentUser != null;

  Future<void> _checkCurrentUser() async {
    final result = await _getCurrentUser();
    result.fold(
      (failure) => _currentUser = null,
      (user) => _currentUser = user,
    );
    notifyListeners();
  }

  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Updated to return the User object on success instead of just a boolean
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
        notifyListeners();
        return null;
      },
      (user) async {
        _currentUser = user;
        _isLoading = false;

        // Store user ID in secure storage
        await _secureStorage.write('userId', user.id);

        notifyListeners();
        return user; // Return the user object on success
      },
    );
  }

  // Updated to return the User object on success instead of just a boolean
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

        // Store user ID in secure storage
        await _secureStorage.write('userId', user.id);

        notifyListeners();
        return user; // Return the user object on success
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

        // Clear secure storage
        await _secureStorage.deleteAll();

        notifyListeners();
      },
    );
  }

  Future<void> refreshCurrentUser() async {
    final result = await _getCurrentUser();
    result.fold((failure) {
      _currentUser = null;
      _errorMessage = failure.message;
    }, (user) => _currentUser = user);
    notifyListeners();
  }
}
