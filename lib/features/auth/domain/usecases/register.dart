// lib/features/auth/domain/usecases/register.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class Register {
  final AuthRepository repository;

  Register(this.repository);

  Future<Either<Failure, User>> call(
    String email,
    String password,
    String firstName,
    String lastName,
    String profession,
  ) {
    return repository.registerWithEmailAndPassword(
      email,
      password,
      firstName,
      lastName,
      profession,
    );
  }
}
