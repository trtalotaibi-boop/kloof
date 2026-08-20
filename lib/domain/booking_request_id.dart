import 'dart:math';

final RegExp _bookingRequestIdPattern = RegExp(r'^[a-f0-9]{32}$');

String createBookingClientRequestId({Random? random}) {
  final source = random ?? Random.secure();
  return List<String>.generate(
    16,
    (_) => source.nextInt(256).toRadixString(16).padLeft(2, '0'),
    growable: false,
  ).join();
}

bool isValidBookingClientRequestId(String value) {
  return _bookingRequestIdPattern.hasMatch(value);
}

class BookingRequestIdTracker {
  final String Function() _createRequestId;
  String? _activeRequestId;

  BookingRequestIdTracker({String Function()? createRequestId})
    : _createRequestId = createRequestId ?? createBookingClientRequestId;

  String begin() {
    return _activeRequestId ??= _createRequestId();
  }

  void reset() {
    _activeRequestId = null;
  }
}
