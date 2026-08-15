import 'package:flutter_test/flutter_test.dart';
import 'package:kloof/domain/booking_slot.dart';

void main() {
  test('slot id is stable and minute-precision', () {
    final slot = BookingSlot(
      barberId: 'barberUid',
      start: DateTime(2026, 8, 4, 9, 5, 42),
    );

    expect(slot.id, 'barberUid--20260804--0905');
    expect(slot.normalizedStart, DateTime(2026, 8, 4, 9, 5));
  });

  test('different barbers and times produce different ids', () {
    final first = BookingSlot(barberId: 'one', start: DateTime(2026, 8, 4, 9));
    final second = BookingSlot(barberId: 'two', start: DateTime(2026, 8, 4, 9));
    final later = BookingSlot(
      barberId: 'one',
      start: DateTime(2026, 8, 4, 9, 30),
    );

    expect({first.id, second.id, later.id}, hasLength(3));
  });
}
