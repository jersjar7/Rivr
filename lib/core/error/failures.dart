// lib/core/error/failures.dart

abstract class Failure {
  final String message;

  Failure({required this.message});
}

class ServerFailure extends Failure {
  ServerFailure({required super.message});
}

class CacheFailure extends Failure {
  CacheFailure({required super.message});
}

class AuthFailure extends Failure {
  AuthFailure({required super.message});
}

class NetworkFailure extends Failure {
  NetworkFailure({required super.message});
}

class LocationFailure extends Failure {
  LocationFailure({required super.message});
}

class DatabaseFailure extends Failure {
  DatabaseFailure({required super.message});
}
