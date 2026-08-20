const Duration riyadhUtcOffset = Duration(hours: 3);

DateTime currentRiyadhDateTime({DateTime? utcNow}) {
  final instant = (utcNow ?? DateTime.now().toUtc()).toUtc();
  return utcInstantToRiyadhWallClock(instant);
}

DateTime riyadhWallClockToUtc({
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
}) {
  return DateTime.utc(year, month, day, hour, minute).subtract(riyadhUtcOffset);
}

DateTime utcInstantToRiyadhWallClock(DateTime instant) {
  final shifted = instant.toUtc().add(riyadhUtcOffset);
  return DateTime.utc(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
    shifted.microsecond,
  );
}

String riyadhDateKey(DateTime instant) {
  final value = utcInstantToRiyadhWallClock(instant);
  return '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
}

String riyadhTimeKey(DateTime instant) {
  final value = utcInstantToRiyadhWallClock(instant);
  return '${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}';
}
