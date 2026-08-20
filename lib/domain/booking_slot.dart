import 'riyadh_time.dart';

class BookingSlot {
  final String barberId;
  final DateTime start;

  const BookingSlot({required this.barberId, required this.start});

  DateTime get normalizedStart {
    final utc = start.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
  }

  String get id {
    final value = normalizedStart;
    final date = riyadhDateKey(value);
    final time = riyadhTimeKey(value);
    return '$barberId--$date--$time';
  }
}
