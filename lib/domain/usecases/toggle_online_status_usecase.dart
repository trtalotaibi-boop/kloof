import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../failures/failure.dart';
import '../repositories/barber_repository.dart';

class ToggleOnlineParams extends Equatable {
  final String barberId;
  final bool isOnline;

  const ToggleOnlineParams({
    required this.barberId,
    required this.isOnline,
  });

  @override
  List<Object?> get props => [barberId, isOnline];
}

class ToggleOnlineStatusUseCase {
  final BarberRepository repository;

  ToggleOnlineStatusUseCase(this.repository);

  Future<Either<Failure, void>> call(ToggleOnlineParams params) async {
    return repository.toggleOnlineStatus(
      barberId: params.barberId,
      isOnline: params.isOnline,
    );
  }
}
