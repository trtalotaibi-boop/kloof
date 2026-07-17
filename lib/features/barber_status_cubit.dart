import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/usecases/toggle_online_status_usecase.dart';

part 'barber_status_state.dart';

class BarberStatusCubit extends Cubit<BarberStatusState> {
  final ToggleOnlineStatusUseCase toggleOnlineStatusUseCase;

  BarberStatusCubit(this.toggleOnlineStatusUseCase) : super(BarberStatusInitial());

  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 400);

  void toggleOnline(String barberId, bool currentValue) {
    final newValue = !currentValue;
    emit(BarberStatusUpdating(isOnline: newValue));

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _commitStatus(barberId: barberId, isOnline: newValue);
    });
  }

  Future<void> _commitStatus({required String barberId, required bool isOnline}) async {
    final result = await toggleOnlineStatusUseCase(
      ToggleOnlineParams(barberId: barberId, isOnline: isOnline),
    );

    if (isClosed) return;

    result.fold(
      (failure) => emit(BarberStatusError(isOnline: !isOnline, message: failure.message)),
      (_) => emit(BarberStatusSuccess(isOnline: isOnline)),
    );
  }
}
