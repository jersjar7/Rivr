// lib/features/auth/domain/usecases/get_current_user.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUser {
  final AuthRepository repository;

  GetCurrentUser(this.repository);

  Future<Either<Failure, User?>> call() async {
    print("GET_CURRENT_USER: Use case called");
    try {
      final result = await repository.getCurrentUser();
      print("GET_CURRENT_USER: Repository returned result");
      return result;
    } catch (e) {
      print("GET_CURRENT_USER: Exception caught: $e");
      return Left(AuthFailure(message: "Error getting current user: $e"));
    }
  }
}
