Map<String, dynamic> barberWorkingHoursData(Map<String, dynamic>? data) {
  final workingHours = data?['workingHours'];
  if (workingHours is Map<String, dynamic>) {
    return workingHours;
  }
  if (workingHours is Map) {
    return Map<String, dynamic>.from(workingHours);
  }
  return <String, dynamic>{};
}

String barberDisplayName(
  Map<String, dynamic>? data, {
  String fallback = '',
}) {
  final preferredName = data?['name']?.toString().trim();
  if (preferredName != null && preferredName.isNotEmpty) {
    return preferredName;
  }

  final legacyName = data?['fullName']?.toString().trim();
  if (legacyName != null && legacyName.isNotEmpty) {
    return legacyName;
  }

  return fallback;
}

bool barberIsOnline(Map<String, dynamic>? data, {bool fallback = false}) {
  final rawValue = data?['isOnline'];
  if (rawValue is bool) {
    return rawValue;
  }
  if (rawValue is String) {
    final normalized = rawValue.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return fallback;
}

String barberServicesSummary(
  Map<String, dynamic>? data, {
  String fallback = 'Haircut • Beard',
}) {
  final rawServices = data?['services'];

  if (rawServices is String) {
    final services = rawServices.trim();
    return services.isEmpty ? fallback : services;
  }

  if (rawServices is List) {
    final names = rawServices
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item['name']?.toString().trim() ?? '';
          }
          if (item is Map) {
            return item['name']?.toString().trim() ?? '';
          }
          return item.toString().trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isNotEmpty) {
      return names.join(' • ');
    }
  }

  return fallback;
}
