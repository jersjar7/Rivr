import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rivr/core/network/network_info.dart';
import 'package:rivr/core/storage/app_database.dart';
import 'package:rivr/core/storage/secure_storage.dart';
import 'package:rivr/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:rivr/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:rivr/features/auth/domain/repositories/auth_repository.dart';
import 'package:rivr/features/auth/domain/usecases/login.dart';
import 'package:rivr/features/auth/domain/usecases/register.dart';
import 'package:rivr/features/auth/domain/usecases/get_current_user.dart';
import 'package:rivr/features/auth/domain/usecases/send_password_reset_email.dart';
import 'package:rivr/features/auth/domain/usecases/sign_out.dart';
import 'package:rivr/features/auth/presentation/providers/auth_provider.dart'
    as app;

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Firebase
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  // Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
  sl.registerLazySingleton<AppDatabase>(() => AppDatabaseImpl());
  sl.registerLazySingleton<SecureStorage>(() => SecureStorageImpl());

  // Register feature-specific dependencies
  _registerAuthDependencies();
  _registerFavoritesDependencies();
  _registerForecastDependencies();
  // Add other feature registrations
}

void _registerAuthDependencies() {
  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(firebaseAuth: sl(), firestore: sl()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => Login(sl()));
  sl.registerLazySingleton(() => Register(sl()));
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => SendPasswordResetEmail(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));

  // Providers
  sl.registerFactory(
    () => app.AuthProvider(
      login: sl(),
      register: sl(),
      getCurrentUser: sl(),
      sendPasswordResetEmail: sl(),
      signOut: sl(),
      secureStorage: sl(),
    ),
  );
}

// Placeholder methods for other features
void _registerFavoritesDependencies() {
  // TODO: Implement favorites dependencies
}

void _registerForecastDependencies() {
  // TODO: Implement forecast dependencies
}
