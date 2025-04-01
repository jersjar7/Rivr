// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/user_profile_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final UserProfileService userProfileService;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.userProfileService,
  });

  @override
  Future<Either<Failure, User>> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.signInWithEmailAndPassword(
          email,
          password,
        );

        // Sync user activity
        await userProfileService.syncUserActivity(user.id);

        return Right(user);
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await remoteDataSource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure(message: 'Failed to sign out'));
    }
  }

  @override
  Future<Either<Failure, bool>> isSignedIn() async {
    try {
      final isSignedIn = await remoteDataSource.isSignedIn();
      return Right(isSignedIn);
    } catch (e) {
      return Left(AuthFailure(message: 'Failed to check authentication state'));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await remoteDataSource.getCurrentUser();

      if (user != null) {
        // Attempt to refresh profile data from Firestore
        try {
          final latestProfile = await userProfileService.getUserProfile(
            user.id,
          );
          if (latestProfile != null) {
            // Return the latest profile data
            return Right(latestProfile);
          }
        } catch (_) {
          // If refresh fails, still return the cached user data
        }
      }

      return Right(user);
    } catch (e) {
      return Left(AuthFailure(message: 'Failed to get current user'));
    }
  }

  @override
  Future<Either<Failure, User>> updateUserProfile(
    String userId, {
    String? firstName,
    String? lastName,
    String? profession,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final updatedUser = await userProfileService.updateUserProfile(
          userId: userId,
          firstName: firstName,
          lastName: lastName,
          profession: profession,
        );

        return Right(updatedUser);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(
          ServerFailure(message: 'Failed to update profile: ${e.toString()}'),
        );
      }
    } else {
      return Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, User>> registerWithEmailAndPassword(
    String email,
    String password,
    String firstName,
    String lastName,
    String profession,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.registerWithEmailAndPassword(
          email,
          password,
          firstName,
          lastName,
          profession,
        );

        // Ensure profile is properly set up
        await userProfileService.setupInitialProfile(
          userId: user.id,
          email: email,
          firstName: firstName,
          lastName: lastName,
          profession: profession,
        );

        return Right(user);
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.sendPasswordResetEmail(email);
        return const Right(null);
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No internet connection'));
    }
  }
}
