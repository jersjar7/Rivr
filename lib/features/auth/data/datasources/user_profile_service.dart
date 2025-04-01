// lib/features/auth/data/datasources/user_profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../../../core/error/exceptions.dart';

/// Service responsible for synchronizing user profile data with Firestore
class UserProfileService {
  final FirebaseFirestore _firestore;

  UserProfileService({required FirebaseFirestore firestore})
    : _firestore = firestore;

  /// Fetches the latest user profile data from Firestore
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        return null;
      }

      final data = docSnapshot.data()!;

      return UserModel(
        id: userId,
        email: data['email'] ?? '',
        firstName: data['first_name'],
        lastName: data['last_name'],
        profession: data['profession'],
      );
    } catch (e) {
      throw ServerException(
        message: 'Failed to get user profile: ${e.toString()}',
      );
    }
  }

  /// Updates the user profile in Firestore
  Future<UserModel> updateUserProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? profession,
    String? email,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        throw ServerException(message: 'User profile not found');
      }

      final currentData = docSnapshot.data();

      // Build update data with only the fields that are provided
      final Map<String, dynamic> updateData = {};

      if (firstName != null) updateData['first_name'] = firstName;
      if (lastName != null) updateData['last_name'] = lastName;
      if (profession != null) updateData['profession'] = profession;
      if (email != null) updateData['email'] = email;

      // Add last_updated timestamp
      updateData['last_updated'] = FieldValue.serverTimestamp();

      // Update the document
      await docRef.update(updateData);

      // Return updated user model
      return UserModel(
        id: userId,
        email: email ?? currentData?['email'] ?? '',
        firstName: firstName ?? currentData?['first_name'],
        lastName: lastName ?? currentData?['last_name'],
        profession: profession ?? currentData?['profession'],
      );
    } catch (e) {
      throw ServerException(
        message: 'Failed to update user profile: ${e.toString()}',
      );
    }
  }

  /// Syncs the user's last activity
  Future<void> syncUserActivity(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'last_activity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silent fail - non-critical operation
      print('Failed to sync user activity: ${e.toString()}');
    }
  }

  /// Sets up the user profile when created for the first time
  Future<void> setupInitialProfile({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    String? profession,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'profession': profession ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
        'last_activity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException(
        message: 'Failed to setup user profile: ${e.toString()}',
      );
    }
  }

  /// Deletes a user profile
  Future<void> deleteUserProfile(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      throw ServerException(
        message: 'Failed to delete user profile: ${e.toString()}',
      );
    }
  }
}
