// lib/features/auth/domain/entities/user.dart
class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? profession;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.profession,
  });
}
