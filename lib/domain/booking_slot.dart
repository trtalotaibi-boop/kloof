class BookingSlot {
  final String barberId;
  final DateTime start;

  const BookingSlot({required this.barberId, required this.start});

  DateTime get normalizedStart =>
      DateTime(start.year, start.month, start.day, start.hour, start.minute);

  String get id {
    final value = normalizedStart;
    final date =
        '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$barberId--$date--$time';
  }
}
