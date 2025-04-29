// lib/features/auth/data/models/user_model.dart
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import '../../domain/entities/user.dart';

class UserModel extends User {
  UserModel({
    required super.uid,
    required super.email,
    super.firstName,
    super.lastName,
    super.profession,
  });

  factory UserModel.fromFirebase(firebase.User firebaseUser) {
    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      firstName: '',
      lastName: '',
      profession: '',
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['id'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      profession: json['profession'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'profession': profession,
    };
  }
}
