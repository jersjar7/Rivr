// lib/features/auth/data/datasources/auth_remote_datasource.dart
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithEmailAndPassword(String email, String password);
  Future<UserModel> registerWithEmailAndPassword(
    String email,
    String password,
    String firstName,
    String lastName,
    String profession,
  );
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();
  Future<bool> isSignedIn();
  Future<UserModel?> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final firebase.FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  @override
  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw AuthException(message: 'User not found');
      }

      return UserModel.fromFirebase(userCredential.user!);
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(message: e.message ?? 'Authentication failed');
    }
  }

  @override
  Future<UserModel> registerWithEmailAndPassword(
    String email,
    String password,
    String firstName,
    String lastName,
    String profession,
  ) async {
    try {
      final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw AuthException(message: 'Registration failed');
      }

      final user = UserModel(
        id: userCredential.user!.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        profession: profession,
      );

      // Save user details to Firestore
      await firestore.collection('users').doc(user.id).set({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'profession': profession,
      });

      return user;
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(message: e.message ?? 'Registration failed');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(
        message: e.message ?? 'Failed to send password reset email',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await firebaseAuth.signOut();
    } catch (e) {
      throw AuthException(message: 'Failed to sign out');
    }
  }

  @override
  Future<bool> isSignedIn() async {
    return firebaseAuth.currentUser != null;
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    try {
      // Get additional user data from Firestore
      final userDoc =
          await firestore.collection('users').doc(firebaseUser.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        return UserModel(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          firstName: userData['first_name'],
          lastName: userData['last_name'],
          profession: userData['profession'],
        );
      } else {
        // Return basic user if Firestore data doesn't exist
        return UserModel.fromFirebase(firebaseUser);
      }
    } catch (e) {
      throw ServerException(message: 'Failed to get user data');
    }
  }
}
