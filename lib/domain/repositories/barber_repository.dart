import 'package:dartz/dartz.dart';
import '../failures/failure.dart';

abstract class BarberRepository {
  Future<Either<Failure, void>> toggleOnlineStatus({
    required String barberId,
    required bool isOnline,
  });
}
