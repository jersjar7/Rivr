// lib/features/auth/data/datasources/auth_remote_datasource.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/firebase_error_mapper.dart';
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
    print("REMOTE DS: signInWithEmailAndPassword called");
    try {
      print("REMOTE DS: Calling Firebase Auth");
      final userCredential = await firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw AuthException(message: 'Authentication request timed out');
            },
          );
      print("REMOTE DS: Firebase Auth returned");

      if (userCredential.user == null) {
        print("REMOTE DS: User is null from Firebase");
        throw AuthException(message: 'User not found');
      }
      print("REMOTE DS: Got user from Firebase: ${userCredential.user!.uid}");

      // Fetch additional user data from Firestore
      print("REMOTE DS: Fetching user data from Firestore");
      final userData = await _getUserDataFromFirestore(
        userCredential.user!.uid,
      );
      print(
        "REMOTE DS: Firestore data fetch completed: ${userData != null ? 'data found' : 'no data'}",
      );

      if (userData != null) {
        print("REMOTE DS: Creating UserModel with Firestore data");
        return UserModel(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          firstName: userData['first_name'],
          lastName: userData['last_name'],
          profession: userData['profession'],
        );
      }

      print("REMOTE DS: Creating UserModel from Firebase only");
      return UserModel.fromFirebase(userCredential.user!);
    } on firebase.FirebaseAuthException catch (e) {
      print("REMOTE DS: FirebaseAuthException: ${e.code} - ${e.message}");
      throw AuthException(message: FirebaseErrorMapper.mapAuthError(e));
    } catch (e) {
      print("REMOTE DS: Unexpected error: $e");
      throw AuthException(message: 'Authentication failed: ${e.toString()}');
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
    print("REMOTE_DS: registerWithEmailAndPassword called");
    try {
      print("REMOTE_DS: Calling Firebase Auth createUserWithEmailAndPassword");
      final userCredential = await firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print("REMOTE_DS: Firebase Auth createUser timed out");
              throw AuthException(message: 'Firebase registration timed out');
            },
          );

      print("REMOTE_DS: Firebase Auth returned");

      if (userCredential.user == null) {
        print("REMOTE_DS: User is null from Firebase");
        throw AuthException(message: 'Registration failed');
      }
      print("REMOTE_DS: Got user from Firebase: ${userCredential.user!.uid}");

      final user = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        profession: profession,
      );

      // Save user details to Firestore - make this non-blocking
      print("REMOTE_DS: Saving user details to Firestore");
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .set({
              'first_name': firstName,
              'last_name': lastName,
              'email': email,
              'profession': profession,
              'created_at': FieldValue.serverTimestamp(),
              'last_login': FieldValue.serverTimestamp(),
            })
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                print("REMOTE_DS: Firestore save timed out");
                // Don't throw here - we'll continue with the user creation
                // The repository will handle setting up the profile later
                return;
              },
            );
        print("REMOTE_DS: User details saved to Firestore");
      } catch (e) {
        print("REMOTE_DS: Error saving to Firestore: $e");
        // Don't throw here - we want to return the user even if Firestore fails
      }

      print("REMOTE_DS: Returning user model");
      return user;
    } on firebase.FirebaseAuthException catch (e) {
      print("REMOTE_DS: FirebaseAuthException: ${e.code} - ${e.message}");
      throw AuthException(message: FirebaseErrorMapper.mapAuthError(e));
    } on AuthException catch (e) {
      print("REMOTE_DS: Caught AuthException: ${e.message}");
      rethrow;
    } catch (e) {
      print("REMOTE_DS: Unexpected error: $e");
      throw AuthException(message: 'Registration failed: ${e.toString()}');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    print("REMOTE_DS: Sending password reset email to $email");
    try {
      await firebaseAuth
          .sendPasswordResetEmail(email: email)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print("REMOTE_DS: Password reset email request timed out");
              throw AuthException(
                message: 'Request timed out. Please try again later.',
              );
            },
          );
      print("REMOTE_DS: Password reset email sent successfully");
    } on firebase.FirebaseAuthException catch (e) {
      print("REMOTE_DS: FirebaseAuthException: ${e.code} - ${e.message}");
      throw AuthException(message: FirebaseErrorMapper.mapAuthError(e));
    } catch (e) {
      print("REMOTE_DS: Error sending password reset email: $e");
      throw AuthException(
        message: 'Failed to send password reset email: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> signOut() async {
    print("REMOTE_DS: Signing out");
    try {
      await firebaseAuth.signOut().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print("REMOTE_DS: Sign out timed out, but continuing");
          // We still return success even on timeout since the local session will be cleared
          return;
        },
      );
      print("REMOTE_DS: Sign out successful");
    } catch (e) {
      print("REMOTE_DS: Error during sign out: $e");
      throw AuthException(message: 'Failed to sign out: ${e.toString()}');
    }
  }

  @override
  Future<bool> isSignedIn() async {
    print("REMOTE_DS: Checking if user is signed in");
    try {
      // This operation is very lightweight, but add a timeout just in case
      final result = await Future.delayed(
        const Duration(milliseconds: 500),
        () => firebaseAuth.currentUser != null,
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print("REMOTE_DS: isSignedIn check timed out");
          // If timeout, assume not signed in for safety
          return false;
        },
      );
      print("REMOTE_DS: isSignedIn check completed: $result");
      return result;
    } catch (e) {
      print("REMOTE_DS: Error in isSignedIn: $e");
      // On any error, assume not signed in for safety
      return false;
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    print("REMOTE_DS: getCurrentUser called");
    final firebaseUser = firebaseAuth.currentUser;
    print(
      "REMOTE_DS: firebaseAuth.currentUser returned: ${firebaseUser != null}",
    );

    if (firebaseUser == null) {
      print("REMOTE_DS: User is null, returning null");
      return null;
    }

    try {
      // Get additional user data from Firestore
      print(
        "REMOTE_DS: Getting user data from Firestore for ${firebaseUser.uid}",
      );
      final userData = await _getUserDataFromFirestore(firebaseUser.uid);
      print(
        "REMOTE_DS: _getUserDataFromFirestore returned: ${userData != null}",
      );

      if (userData != null) {
        // Update last_seen timestamp
        try {
          print("REMOTE_DS: Updating last_seen timestamp");
          await firestore.collection('users').doc(firebaseUser.uid).update({
            'last_seen': FieldValue.serverTimestamp(),
          });
          print("REMOTE_DS: Timestamp updated successfully");
        } catch (e) {
          print("REMOTE_DS: Error updating timestamp: $e");
          // Continue even if timestamp update fails
        }

        print("REMOTE_DS: Creating UserModel with Firestore data");
        return UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          firstName: userData['first_name'],
          lastName: userData['last_name'],
          profession: userData['profession'],
        );
      } else {
        // Return basic user if Firestore data doesn't exist
        print("REMOTE_DS: No Firestore data, creating basic UserModel");
        return UserModel.fromFirebase(firebaseUser);
      }
    } catch (e) {
      print("REMOTE_DS: Error in getCurrentUser: $e");
      throw ServerException(
        message: 'Failed to get user data: ${e.toString()}',
      );
    }
  }

  // Helper method to get user data from Firestore
  Future<Map<String, dynamic>?> _getUserDataFromFirestore(String uid) async {
    print("REMOTE_DS: _getUserDataFromFirestore called for $uid");
    try {
      // Add timeout to prevent hanging
      final userDoc = await firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              print("REMOTE_DS: Firestore get timed out");
              throw TimeoutException("Firestore query timed out");
            },
          );

      print("REMOTE_DS: Firestore returned document, exists=${userDoc.exists}");
      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data()!;
      }
      return null;
    } catch (e) {
      print("REMOTE_DS: Error getting Firestore document: $e");
      // Return null instead of throwing to make this method more resilient
      return null;
    }
  }
}
