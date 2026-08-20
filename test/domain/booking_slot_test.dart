import 'package:flutter_test/flutter_test.dart';
import 'package:kloof/domain/booking_slot.dart';
import 'package:kloof/domain/riyadh_time.dart';

void main() {
  test('slot id is stable and minute-precision', () {
    final slot = BookingSlot(
      barberId: 'barberUid',
      start: DateTime.utc(2026, 8, 4, 6, 5, 42),
    );

    expect(slot.id, 'barberUid--20260804--0905');
    expect(slot.normalizedStart, DateTime.utc(2026, 8, 4, 6, 5));
  });

  test('different barbers and times produce different ids', () {
    final first = BookingSlot(
      barberId: 'one',
      start: DateTime.utc(2026, 8, 4, 6),
    );
    final second = BookingSlot(
      barberId: 'two',
      start: DateTime.utc(2026, 8, 4, 6),
    );
    final later = BookingSlot(
      barberId: 'one',
      start: DateTime.utc(2026, 8, 4, 6, 30),
    );

    expect({first.id, second.id, later.id}, hasLength(3));
  });

  test('Flutter slot id matches Backend Riyadh yyyyMMdd and HHmm', () {
    final instant = riyadhWallClockToUtc(
      year: 2026,
      month: 8,
      day: 20,
      hour: 20,
      minute: 0,
    );

    expect(
      BookingSlot(barberId: 'barber', start: instant).id,
      'barber--20260820--2000',
    );
  });

  test('45-minute service produces three 15-minute Saudi locks', () {
    final start = DateTime.utc(2026, 8, 20, 17);
    final ids = [
      for (var offset = 0; offset < 45; offset += 15)
        BookingSlot(
          barberId: 'barber',
          start: start.add(Duration(minutes: offset)),
        ).id,
    ];

    expect(ids, [
      'barber--20260820--2000',
      'barber--20260820--2015',
      'barber--20260820--2030',
    ]);
  });

  test('60-minute service produces four 15-minute Saudi locks', () {
    final start = DateTime.utc(2026, 8, 20, 17);
    final ids = [
      for (var offset = 0; offset < 60; offset += 15)
        BookingSlot(
          barberId: 'barber',
          start: start.add(Duration(minutes: offset)),
        ).id,
    ];

    expect(ids, [
      'barber--20260820--2000',
      'barber--20260820--2015',
      'barber--20260820--2030',
      'barber--20260820--2045',
    ]);
  });
}
