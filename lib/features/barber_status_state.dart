part of 'barber_status_cubit.dart';

abstract class BarberStatusState extends Equatable {
  final bool isOnline;

  const BarberStatusState({required this.isOnline});

  @override
  List<Object> get props => [isOnline];
}

class BarberStatusInitial extends BarberStatusState {
  const BarberStatusInitial() : super(isOnline: false);
}

class BarberStatusUpdating extends BarberStatusState {
  const BarberStatusUpdating({required bool isOnline})
      : super(isOnline: isOnline);
}

class BarberStatusSuccess extends BarberStatusState {
  const BarberStatusSuccess({required bool isOnline})
      : super(isOnline: isOnline);
}

class BarberStatusError extends BarberStatusState {
  final String message;

  const BarberStatusError({
    required bool isOnline,
    required this.message,
  }) : super(isOnline: isOnline);

  @override
  List<Object> get props => [isOnline, message];
}
