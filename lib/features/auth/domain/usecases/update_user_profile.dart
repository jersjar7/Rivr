// lib/features/auth/domain/usecases/update_user_profile.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class UpdateUserProfile {
  final AuthRepository repository;

  UpdateUserProfile(this.repository);

  Future<Either<Failure, User>> call(
    String userId, {
    String? firstName,
    String? lastName,
    String? profession,
  }) {
    return repository.updateUserProfile(
      userId,
      firstName: firstName,
      lastName: lastName,
      profession: profession,
    );
  }
}
