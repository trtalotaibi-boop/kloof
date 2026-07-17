import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import '../../domain/failures/failure.dart';
import '../../domain/repositories/barber_repository.dart';

class BarberRepositoryImpl implements BarberRepository {
  final FirebaseFirestore firestore;

  BarberRepositoryImpl({required this.firestore});

  @override
  Future<Either<Failure, void>> toggleOnlineStatus({
    required String barberId,
    required bool isOnline,
  }) async {
    try {
      await firestore.collection('barbers').doc(barberId).update({
        'isOnline': isOnline,
      });
      return Right(null);
    } catch (e) {
      return Left(FirestoreFailure(message: e.toString()));
    }
  }
}
