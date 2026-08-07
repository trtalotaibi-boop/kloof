import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kloof/l10n/app_localizations.dart';

import 'booking_confirmation_screen.dart';
import 'login_screen.dart';

class BookingScreen extends StatefulWidget {
  final String barberId;
  final String barberName;
  final String service;

  const BookingScreen({
    super.key,
    required this.barberId,
    required this.barberName,
    required this.service,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  bool _isLoadingServices = true;
  bool _isLoadingAvailability = true;
  bool _isSubmitting = false;
  bool _isBarberOnline = false;
  List<_ServiceOption> _serviceOptions = [];
  List<_TimeSlot> _availableTimes = [];
  _ServiceOption? _selectedService;
  _TimeSlot? _selectedTime;

  @override
  void initState() {
    super.initState();
    _loadBookingOptions();
  }

  List<String> _splitServiceNames(String raw) {
    return raw
        .replaceAll('•', ',')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _loadBookingOptions() async {
    try {
      final barberDoc = await FirebaseFirestore.instance
          .collection('barbers')
          .doc(widget.barberId)
          .get();

      final options = <_ServiceOption>[];
      final seenNames = <String>{};
      var isOnline = false;
      var availableTimes = <_TimeSlot>[];

      if (barberDoc.exists) {
        final data = barberDoc.data() ?? <String, dynamic>{};
        isOnline = data['isOnline'] == true;
        final rawServices = data['services'];

        if (rawServices is List) {
          for (final item in rawServices) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final rawPrice = map['price'];
              final price = rawPrice is num
                  ? rawPrice.toDouble()
                  : double.tryParse(rawPrice?.toString() ?? '');
              final names = _splitServiceNames(
                (map['name'] ?? '').toString().trim(),
              );
              for (final name in names) {
                final key = name.toLowerCase();
                if (!seenNames.add(key)) continue;
                options.add(_ServiceOption(name: name, price: price));
              }
            } else {
              for (final name in _splitServiceNames(item.toString())) {
                final key = name.toLowerCase();
                if (!seenNames.add(key)) continue;
                options.add(_ServiceOption(name: name, price: null));
              }
            }
          }
        }

        if (isOnline && mounted) {
          availableTimes = await _loadAvailableTimes(widget.barberId, data);
        }
      }

      if (options.isEmpty) {
        for (final name in _splitServiceNames(widget.service)) {
          final key = name.toLowerCase();
          if (!seenNames.add(key)) continue;
          options.add(_ServiceOption(name: name, price: null));
        }
      }

      if (!mounted) return;
      setState(() {
        _serviceOptions = options;
        _selectedService = options.isNotEmpty ? options.first : null;
        _isBarberOnline = isOnline;
        _availableTimes = availableTimes;
        _isLoadingServices = false;
        _isLoadingAvailability = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingServices = false;
        _isLoadingAvailability = false;
      });
    }
  }

  TimeOfDay? _parseSavedTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.trim().split(' ');
    final hm = parts.first.split(':');
    if (hm.length != 2) return null;

    var hour = int.tryParse(hm[0]);
    final minute = int.tryParse(hm[1]);
    if (hour == null || minute == null) return null;

    if (parts.length > 1) {
      final period = parts[1].toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _minutesOfDay(TimeOfDay time) => (time.hour * 60) + time.minute;

  Future<List<_TimeSlot>> _loadAvailableTimes(
    String barberId,
    Map<String, dynamic> barberData,
  ) async {
    final now = DateTime.now();
    final bookingDate = DateTime(now.year, now.month, now.day);
    final workingHours = Map<String, dynamic>.from(
      barberData['workingHours'] ?? <String, dynamic>{},
    );

    const dayCodes = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final workingDays = List<String>.from(
      workingHours['workingDays'] ?? dayCodes,
    );
    if (!workingDays.contains(dayCodes[now.weekday - 1])) return <_TimeSlot>[];

    final opening = _parseSavedTime(workingHours['openingTime']?.toString()) ??
        const TimeOfDay(hour: 8, minute: 0);
    final closing = _parseSavedTime(workingHours['closingTime']?.toString()) ??
        const TimeOfDay(hour: 23, minute: 0);
    final durationRaw = workingHours['appointmentDuration'];
    final duration = durationRaw is num && durationRaw.toInt() > 0
        ? durationRaw.toInt()
        : 30;
    final breakStart = _parseSavedTime(workingHours['breakStart']?.toString());
    final breakEnd = _parseSavedTime(workingHours['breakEnd']?.toString());

    final existingSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('barberId', isEqualTo: barberId)
        .where('bookingDate', isEqualTo: Timestamp.fromDate(bookingDate))
        .limit(100)
        .get();

    final bookedLabels = <String>{};
    final bookedMinutes = <int>{};
    for (final doc in existingSnapshot.docs) {
      final data = doc.data();
      if ((data['status']?.toString() ?? 'pending') == 'rejected') continue;
      final label = data['selectedTime']?.toString() ?? '';
      if (label.isNotEmpty) bookedLabels.add(label);
      final rawMinutes = data['selectedTimeMinutes'];
      if (rawMinutes is num) bookedMinutes.add(rawMinutes.toInt());
    }

    if (!mounted) return <_TimeSlot>[];
    final materialLocalizations = MaterialLocalizations.of(context);
    final openingMinutes = _minutesOfDay(opening);
    final closingMinutes = _minutesOfDay(closing);
    final nowMinutes = (now.hour * 60) + now.minute;
    final breakStartMinutes = breakStart == null ? null : _minutesOfDay(breakStart);
    final breakEndMinutes = breakEnd == null ? null : _minutesOfDay(breakEnd);
    final slots = <_TimeSlot>[];

    for (
      var start = openingMinutes;
      start + duration <= closingMinutes;
      start += duration
    ) {
      if (start <= nowMinutes) continue;

      final overlapsBreak =
          breakStartMinutes != null &&
          breakEndMinutes != null &&
          start < breakEndMinutes &&
          start + duration > breakStartMinutes;
      if (overlapsBreak) continue;

      final time = TimeOfDay(hour: start ~/ 60, minute: start % 60);
      final label = materialLocalizations.formatTimeOfDay(time);
      if (bookedMinutes.contains(start) || bookedLabels.contains(label)) continue;
      slots.add(_TimeSlot(label: label, minutes: start));
    }

    return slots;
  }

  String _localizedServiceName(String rawName, AppLocalizations l10n) {
    final normalized = rawName.trim().toLowerCase();
    switch (normalized) {
      case 'haircut':
      case 'حلاقة الرأس':
        return l10n.serviceHaircut;
      case 'beard':
      case 'beard trim':
      case 'حلاقة الدقن':
        return l10n.serviceBeard;
      case 'haircut + beard':
      case 'حلاقة الرأس والدقن':
        return l10n.barberProfileServiceHaircutAndBeard;
      case 'kids':
      case 'kids haircut':
      case 'حلاقة أطفال':
        return l10n.serviceKidsHaircut;
      case 'full head shave (zero cut)':
      case 'full head shave':
      case 'zero cut':
      case 'حلاقة كاملة (زيرو)':
      case 'حلاقة الرأس بالمكينة':
        return l10n.serviceFullHeadShave;
      default:
        return rawName.trim();
    }
  }

  String _serviceLabel(_ServiceOption option, AppLocalizations l10n) {
    final service = _localizedServiceName(option.name, l10n);
    if (option.price == null) return service;
    final isWhole = option.price == option.price!.toInt();
    final price = isWhole
        ? option.price!.toInt().toString()
        : option.price!.toStringAsFixed(2);
    return l10n.bookingServicePriceLabel(service, price);
  }

  Future<void> _createNotification({
    required String recipientId,
    required String message,
    required String bookingId,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'recipientId': recipientId,
      'message': message,
      'bookingId': bookingId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _onConfirmBooking() async {
    final l10n = AppLocalizations.of(context);
    if (_isSubmitting) return;

    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bookingSelectServiceError)),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bookingSelectTimeError)),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final selectedService = _selectedService!;
    final selectedTime = _selectedTime!;

    try {
      final barberDoc = await FirebaseFirestore.instance
          .collection('barbers')
          .doc(widget.barberId)
          .get();

      if (!barberDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookingBarberNotFound)),
        );
        return;
      }

      if (barberDoc.data()?['isOnline'] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookingBarberOffline)),
        );
        return;
      }

      final now = DateTime.now();
      final bookingDate = DateTime(now.year, now.month, now.day);
      final barberId = widget.barberId;

      final existingSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('barberId', isEqualTo: barberId)
          .where('bookingDate', isEqualTo: Timestamp.fromDate(bookingDate))
          .limit(100)
          .get();

      final slotAlreadyBooked = existingSnapshot.docs.any((doc) {
        final data = doc.data();
        if ((data['status']?.toString() ?? 'pending') == 'rejected') {
          return false;
        }
        final rawMinutes = data['selectedTimeMinutes'];
        if (rawMinutes is num && rawMinutes.toInt() == selectedTime.minutes) {
          return true;
        }
        return data['selectedTime']?.toString() == selectedTime.label;
      });

      if (slotAlreadyBooked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookingSlotAlreadyBooked)),
        );
        return;
      }

      final customerId = currentUser.uid;
      final bookingRef = await FirebaseFirestore.instance
          .collection('bookings')
          .add({
            'barberId': barberId,
            'barberName': widget.barberName,
            'customerId': customerId,
            'service': selectedService.name,
            'servicePrice': selectedService.price,
            'selectedTime': selectedTime.label,
            'selectedTimeMinutes': selectedTime.minutes,
            'bookingDate': Timestamp.fromDate(bookingDate),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

      await _createNotification(
        recipientId: customerId,
        message: l10n.notificationMessageBookingSubmitted,
        bookingId: bookingRef.id,
      );
      await _createNotification(
        recipientId: barberId,
        message: l10n.notificationMessageNewBookingRequest,
        bookingId: bookingRef.id,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bookingConfirmFailed)),
      );
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingConfirmationScreen(
          barberName: widget.barberName,
          service: selectedService.name,
          servicePrice: selectedService.price,
          selectedDate: DateTime.now(),
          selectedTime: selectedTime.label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          l10n.bookingTitle,
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(20),
                child: ListView(
                  children: [
                    Text(
                      widget.barberName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.bookingSelectService,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingServices)
                      const Center(child: CircularProgressIndicator())
                    else if (_serviceOptions.isEmpty)
                      Text(
                        l10n.bookingNoServicesAvailable,
                        style: const TextStyle(color: Colors.black54),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _serviceOptions.map((service) {
                          final isSelected =
                              _selectedService?.name == service.name;
                          return ChoiceChip(
                            label: Text(_serviceLabel(service, l10n)),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedService = service;
                              });
                            },
                            selectedColor: Colors.black,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                            side: const BorderSide(color: Colors.black26),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.bookingAvailableTimes,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingAvailability)
                      const Center(child: CircularProgressIndicator())
                    else if (!_isBarberOnline)
                      Text(
                        l10n.bookingBarberOffline,
                        style: const TextStyle(color: Colors.black54),
                      )
                    else if (_availableTimes.isEmpty)
                      Text(
                        l10n.bookingNoAvailableTimesToday,
                        style: const TextStyle(color: Colors.black54),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTimes.map((time) {
                          final isSelected =
                              _selectedTime?.minutes == time.minutes;
                          return ChoiceChip(
                            label: Text(time.label),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedTime = time;
                              });
                            },
                            selectedColor: Colors.black,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                            side: const BorderSide(color: Colors.black26),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Container(
              color: const Color(0xFFF8F8F8),
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _onConfirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.bookingConfirmAction,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceOption {
  final String name;
  final double? price;

  const _ServiceOption({required this.name, required this.price});
}

class _TimeSlot {
  final String label;
  final int minutes;

  const _TimeSlot({required this.label, required this.minutes});
}
