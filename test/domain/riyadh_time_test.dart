import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:kloof/domain/riyadh_time.dart';

void main() {
  test('Saudi 20:00 is represented by 17:00Z', () {
    final instant = riyadhWallClockToUtc(
      year: 2026,
      month: 8,
      day: 20,
      hour: 20,
      minute: 0,
    );

    expect(instant, DateTime.utc(2026, 8, 20, 17));
    expect(utcInstantToRiyadhWallClock(instant), DateTime.utc(2026, 8, 20, 20));
  });

  test('business conversion is independent of simulated device timezone', () {
    final scenarios =
        <
          String,
          ({DateTime date, Duration deviceOffset, int expectedDeviceHour})
        >{
          'Riyadh': (
            date: DateTime.utc(2026, 8, 20),
            deviceOffset: const Duration(hours: 3),
            expectedDeviceHour: 20,
          ),
          'London summer': (
            date: DateTime.utc(2026, 8, 20),
            deviceOffset: const Duration(hours: 1),
            expectedDeviceHour: 18,
          ),
          'London winter': (
            date: DateTime.utc(2026, 1, 20),
            deviceOffset: Duration.zero,
            expectedDeviceHour: 17,
          ),
          'New York summer': (
            date: DateTime.utc(2026, 8, 20),
            deviceOffset: const Duration(hours: -4),
            expectedDeviceHour: 13,
          ),
          'New York winter': (
            date: DateTime.utc(2026, 1, 20),
            deviceOffset: const Duration(hours: -5),
            expectedDeviceHour: 12,
          ),
        };

    for (final entry in scenarios.entries) {
      final date = entry.value.date;
      final instant = riyadhWallClockToUtc(
        year: date.year,
        month: date.month,
        day: date.day,
        hour: 20,
        minute: 0,
      );
      final simulatedDeviceWallClock = instant.add(entry.value.deviceOffset);

      expect(instant.hour, 17, reason: entry.key);
      expect(utcInstantToRiyadhWallClock(instant).hour, 20, reason: entry.key);
      expect(
        simulatedDeviceWallClock.hour,
        entry.value.expectedDeviceHour,
        reason: entry.key,
      );
    }
  });

  test('midnight and adjacent date boundaries use the Saudi date', () {
    expect(
      riyadhWallClockToUtc(year: 2026, month: 8, day: 20, hour: 0, minute: 0),
      DateTime.utc(2026, 8, 19, 21),
    );
    expect(
      utcInstantToRiyadhWallClock(DateTime.utc(2026, 8, 19, 20, 59)),
      DateTime.utc(2026, 8, 19, 23, 59),
    );
    expect(
      utcInstantToRiyadhWallClock(DateTime.utc(2026, 8, 19, 21)),
      DateTime.utc(2026, 8, 20),
    );
  });

  test(
    'booking date representation stays on the Saudi calendar date',
    () async {
      await initializeDateFormatting('en');
      final saudiMidnightInstant = DateTime.utc(2026, 8, 19, 21);
      final displayValue = utcInstantToRiyadhWallClock(saudiMidnightInstant);

      expect(displayValue.year, 2026);
      expect(displayValue.month, 8);
      expect(displayValue.day, 20);
      expect(DateFormat('yyyy-MM-dd', 'en').format(displayValue), '2026-08-20');
      expect(riyadhDateKey(saudiMidnightInstant), '20260820');
      expect(riyadhTimeKey(saudiMidnightInstant), '0000');
    },
  );

  test('current Saudi time derives from an injected UTC instant', () {
    expect(
      currentRiyadhDateTime(utcNow: DateTime.utc(2026, 8, 20, 21, 30)),
      DateTime.utc(2026, 8, 21, 0, 30),
    );
  });
}
