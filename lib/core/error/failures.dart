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
