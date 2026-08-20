import 'package:flutter_test/flutter_test.dart';
import 'package:kloof/domain/booking_request_id.dart';

void main() {
  test('booking request IDs are secure-format unique values', () {
    final values = List.generate(100, (_) => createBookingClientRequestId());

    expect(values.toSet(), hasLength(values.length));
    expect(values.every(isValidBookingClientRequestId), isTrue);
  });

  test('booking request ID validation rejects malformed values', () {
    expect(isValidBookingClientRequestId(List.filled(32, '0').join()), isTrue);
    expect(isValidBookingClientRequestId(List.filled(32, 'A').join()), isFalse);
    expect(isValidBookingClientRequestId(List.filled(31, '0').join()), isFalse);
    expect(isValidBookingClientRequestId(List.filled(33, '0').join()), isFalse);
    expect(isValidBookingClientRequestId('request-id-not-random'), isFalse);
  });

  test('request tracker reuses retries and resets for a new attempt', () {
    var sequence = 0;
    final tracker = BookingRequestIdTracker(
      createRequestId: () => 'request-${sequence++}',
    );

    final firstAttempt = tracker.begin();
    expect(tracker.begin(), firstAttempt);

    tracker.reset();
    expect(tracker.begin(), isNot(firstAttempt));
  });
}
