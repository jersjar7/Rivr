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
    print("AUTH REPO: signInWithEmailAndPassword called");
    if (await networkInfo.isConnected) {
      print("AUTH REPO: Network is connected");
      try {
        print("AUTH REPO: Calling remote data source");
        final user = await remoteDataSource.signInWithEmailAndPassword(
          email,
          password,
        );
        print("AUTH REPO: Remote data source returned successfully");

        // Sync user activity in the background
        print("AUTH REPO: Scheduling user activity sync in background");
        // Use a fire-and-forget approach for non-critical operation
        userProfileService.syncUserActivity(user.uid).catchError((e) {
          print("AUTH REPO: Background sync error: $e");
        });

        print("AUTH REPO: Returning user");
        return Right(user);
      } on AuthException catch (e) {
        print("AUTH REPO: AuthException caught: ${e.message}");
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        print("AUTH REPO: Unexpected error: $e");
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      print("AUTH REPO: No internet connection");
      return Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    print("AUTH REPO: Attempting to sign out");
    try {
      await remoteDataSource.signOut().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print("AUTH REPO: Sign out timed out");
          // We can still consider this a "success" since we'll clear local auth data
          return;
        },
      );
      print("AUTH REPO: Sign out successful");
      return const Right(null);
    } catch (e) {
      print("AUTH REPO: Error during sign out: $e");
      // Even if remote sign out fails, we can still consider this a "success"
      // from the user's perspective since we'll clear local auth data
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, bool>> isSignedIn() async {
    print("AUTH REPO: Checking if user is signed in");
    try {
      final isSignedIn = await remoteDataSource.isSignedIn().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print("AUTH REPO: isSignedIn check timed out");
          // If timeout, assume not signed in for safety
          return false;
        },
      );
      print("AUTH REPO: isSignedIn check completed: $isSignedIn");
      return Right(isSignedIn);
    } catch (e) {
      print("AUTH REPO: Error checking authentication state: $e");
      // Return false rather than failure for better UX
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    print("AUTH_REPO: getCurrentUser called");
    try {
      print("AUTH_REPO: Calling remoteDataSource.getCurrentUser");
      final user = await remoteDataSource.getCurrentUser();
      print(
        "AUTH_REPO: remoteDataSource.getCurrentUser returned: ${user != null}",
      );

      if (user != null) {
        // Attempt to refresh profile data from Firestore
        try {
          print("AUTH_REPO: Getting latest profile from Firestore");
          final latestProfile = await userProfileService.getUserProfile(
            user.uid,
          );
          print("AUTH_REPO: getUserProfile returned: ${latestProfile != null}");

          if (latestProfile != null) {
            // Return the latest profile data
            return Right(latestProfile);
          }
        } catch (e) {
          print("AUTH_REPO: Error refreshing profile: $e");
          // If refresh fails, still return the cached user data
        }
      }

      print("AUTH_REPO: Returning user: ${user != null}");
      return Right(user);
    } catch (e) {
      print("AUTH_REPO: Error in getCurrentUser: $e");
      return Left(AuthFailure(message: 'Failed to get current user: $e'));
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
    print("AUTH REPO: registerWithEmailAndPassword called");
    if (await networkInfo.isConnected) {
      print("AUTH REPO: Network is connected");
      try {
        print("AUTH REPO: Calling remote data source");
        final user = await remoteDataSource
            .registerWithEmailAndPassword(
              email,
              password,
              firstName,
              lastName,
              profession,
            )
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                print("AUTH REPO: Remote data source timed out");
                throw AuthException(message: 'Registration request timed out');
              },
            );

        print("AUTH REPO: Remote data source returned successfully");

        // Replace await with background processing for non-critical setup
        print("AUTH REPO: Setting up initial profile in background");
        userProfileService
            .setupInitialProfile(
              userId: user.uid,
              email: email,
              firstName: firstName,
              lastName: lastName,
              profession: profession,
            )
            .catchError((e) {
              print("AUTH REPO: Error in background profile setup: $e");
            });

        print("AUTH REPO: Returning user");
        return Right(user);
      } on AuthException catch (e) {
        print("AUTH REPO: AuthException caught: ${e.message}");
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        print("AUTH REPO: Unexpected error: $e");
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      print("AUTH REPO: No internet connection");
      return Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    print("AUTH REPO: Attempting to send password reset email");
    if (await networkInfo.isConnected) {
      print("AUTH REPO: Network is connected");
      try {
        await remoteDataSource
            .sendPasswordResetEmail(email)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                print("AUTH REPO: Password reset email request timed out");
                throw AuthException(
                  message: 'Request timed out. Please try again later.',
                );
              },
            );
        print("AUTH REPO: Password reset email sent successfully");
        return const Right(null);
      } on AuthException catch (e) {
        print("AUTH REPO: AuthException caught: ${e.message}");
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        print("AUTH REPO: Unexpected error: $e");
        return Left(
          ServerFailure(
            message: 'Failed to send password reset email: ${e.toString()}',
          ),
        );
      }
    } else {
      print("AUTH REPO: No internet connection");
      return Left(
        NetworkFailure(
          message:
              'No internet connection. Please check your network and try again.',
        ),
      );
    }
  }
}
