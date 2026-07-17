abstract class Failure {
  final String message;
  Failure({required this.message});
}

class FirestoreFailure extends Failure {
  FirestoreFailure({required super.message});
}

class UnknownFailure extends Failure {
  UnknownFailure({required super.message});
}
