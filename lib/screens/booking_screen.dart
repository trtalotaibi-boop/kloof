import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

import '../data/booking_store.dart';
import '../domain/booking_slot.dart';

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
  String? _selectedTime;
  DateTime? _selectedSlotStart;
  bool _isLoadingServices = true;
  bool _isLoadingAvailability = true;
  bool _isSubmitting = false;
  bool _isBarberOnline = false;
  Map<String, dynamic>? _barberData;
  List<_ServiceOption> _serviceOptions = [];
  List<_BookingSlotOption> _availableTimes = [];
  _ServiceOption? _selectedService;

  List<String> _splitServiceNames(String raw) {
    return raw
        .replaceAll('•', ',')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadServiceOptions();
  }

  Future<void> _loadServiceOptions() async {
    try {
      final barberDoc = await FirebaseFirestore.instance
          .collection('barbers')
          .doc(widget.barberId)
          .get();

      final options = <_ServiceOption>[];
      final seenNames = <String>{};
      var isOnline = false;
      if (barberDoc.exists) {
        final data = barberDoc.data() ?? <String, dynamic>{};
        isOnline = data['isOnline'] == true;
        final rawServices = data['services'];

        if (rawServices is List) {
          for (final item in rawServices) {
            if (item is Map<String, dynamic>) {
              final priceRaw = item['price'];
              final price = priceRaw is num
                  ? priceRaw.toDouble()
                  : double.tryParse(priceRaw?.toString() ?? '');
              final durationRaw = item['duration'];
              final duration = durationRaw is num
                  ? durationRaw.toInt()
                  : int.tryParse(durationRaw?.toString() ?? '');
              final names = _splitServiceNames(
                (item['name'] ?? '').toString().trim(),
              );
              for (final name in names) {
                final key = name.toLowerCase();
                if (seenNames.contains(key)) continue;
                seenNames.add(key);
                options.add(
                  _ServiceOption(name: name, price: price, duration: duration),
                );
              }
              continue;
            }

            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final priceRaw = map['price'];
              final price = priceRaw is num
                  ? priceRaw.toDouble()
                  : double.tryParse(priceRaw?.toString() ?? '');
              final durationRaw = map['duration'];
              final duration = durationRaw is num
                  ? durationRaw.toInt()
                  : int.tryParse(durationRaw?.toString() ?? '');
              final names = _splitServiceNames(
                (map['name'] ?? '').toString().trim(),
              );
              for (final name in names) {
                final key = name.toLowerCase();
                if (seenNames.contains(key)) continue;
                seenNames.add(key);
                options.add(
                  _ServiceOption(name: name, price: price, duration: duration),
                );
              }
              continue;
            }

            final names = _splitServiceNames(item.toString().trim());
            for (final name in names) {
              final key = name.toLowerCase();
              if (seenNames.contains(key)) continue;
              seenNames.add(key);
              options.add(
                _ServiceOption(name: name, price: null, duration: null),
              );
            }
          }
        }
      }

      if (options.isEmpty) {
        final fallback = _splitServiceNames(widget.service);
        for (final name in fallback) {
          options.add(_ServiceOption(name: name, price: null, duration: null));
        }
      }

      final selectedService = options.isNotEmpty ? options.first : null;
      final barberData = barberDoc.data();
      final availableTimes = isOnline && selectedService != null
          ? await _loadAvailableTimes(
              widget.barberId,
              barberData ?? <String, dynamic>{},
              selectedService.duration,
            )
          : <_BookingSlotOption>[];

      if (!mounted) return;
      setState(() {
        _serviceOptions = options;
        _selectedService = selectedService;
        _isBarberOnline = isOnline;
        _barberData = barberData;
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
    final hourMinute = parts.first.split(':');
    if (hourMinute.length != 2) return null;

    var hour = int.tryParse(hourMinute[0]);
    final minute = int.tryParse(hourMinute[1]);
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

  Future<List<_BookingSlotOption>> _loadAvailableTimes(
    String barberId,
    Map<String, dynamic> barberData,
    int? serviceDuration,
  ) async {
    if (serviceDuration == null || serviceDuration <= 0) {
      return <_BookingSlotOption>[];
    }
    final materialLocalizations = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final bookingDate = DateTime(now.year, now.month, now.day);
    final workingHours = Map<String, dynamic>.from(
      barberData['workingHours'] ?? <String, dynamic>{},
    );
    const dayCodes = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final workingDays = List<String>.from(
      workingHours['workingDays'] ?? dayCodes,
    );
    if (!workingDays.contains(dayCodes[now.weekday - 1])) {
      return <_BookingSlotOption>[];
    }

    final opening =
        _parseSavedTime(workingHours['openingTime']?.toString()) ??
        const TimeOfDay(hour: 8, minute: 0);
    final closing =
        _parseSavedTime(workingHours['closingTime']?.toString()) ??
        const TimeOfDay(hour: 23, minute: 0);
    final intervalRaw = workingHours['appointmentDuration'];
    final interval = intervalRaw is num && intervalRaw.toInt() > 0
        ? intervalRaw.toInt()
        : 30;
    final breakStart = _parseSavedTime(workingHours['breakStart']?.toString());
    final breakEnd = _parseSavedTime(workingHours['breakEnd']?.toString());

    final openingMinutes = _minutesOfDay(opening);
    final closingMinutes = _minutesOfDay(closing);
    final nowMinutes = (now.hour * 60) + now.minute;
    final breakStartMinutes = breakStart == null
        ? null
        : _minutesOfDay(breakStart);
    final breakEndMinutes = breakEnd == null ? null : _minutesOfDay(breakEnd);
    final slots = <_BookingSlotOption>[];
    final candidates = <(_BookingSlotOption, List<String>)>[];
    final lockIds = <String>{};

    for (
      var start = openingMinutes;
      start + serviceDuration <= closingMinutes;
      start += interval
    ) {
      if (start <= nowMinutes) continue;
      final overlapsBreak =
          breakStartMinutes != null &&
          breakEndMinutes != null &&
          start < breakEndMinutes &&
          start + serviceDuration > breakStartMinutes;
      if (overlapsBreak) continue;

      final time = TimeOfDay(hour: start ~/ 60, minute: start % 60);
      final label = materialLocalizations.formatTimeOfDay(time);
      final slotStart = DateTime(
        bookingDate.year,
        bookingDate.month,
        bookingDate.day,
        time.hour,
        time.minute,
      );
      final candidateLockIds = <String>[];
      for (var offset = 0; offset < serviceDuration; offset += interval) {
        final segmentStart = slotStart.add(Duration(minutes: offset));
        final lockId = BookingSlot(barberId: barberId, start: segmentStart).id;
        candidateLockIds.add(lockId);
        lockIds.add(lockId);
      }
      candidates.add((
        _BookingSlotOption(label: label, start: slotStart),
        candidateLockIds,
      ));
    }

    final lockSnapshots = await Future.wait(
      lockIds.map(
        (slotId) => FirebaseFirestore.instance
            .collection('bookingSlots')
            .doc(slotId)
            .get(),
      ),
    );
    final occupiedLockIds = lockSnapshots
        .where((snapshot) => snapshot.exists)
        .map((snapshot) => snapshot.id)
        .toSet();
    for (final (candidate, candidateLockIds) in candidates) {
      if (!candidateLockIds.any(occupiedLockIds.contains)) {
        slots.add(candidate);
      }
    }
    return slots;
  }

  Future<void> _selectService(_ServiceOption service) async {
    final barberData = _barberData;
    setState(() {
      _selectedService = service;
      _selectedTime = null;
      _selectedSlotStart = null;
      _isLoadingAvailability = true;
    });

    final times = _isBarberOnline && barberData != null
        ? await _loadAvailableTimes(
            widget.barberId,
            barberData,
            service.duration,
          )
        : <_BookingSlotOption>[];
    if (!mounted || _selectedService?.name != service.name) return;
    setState(() {
      _availableTimes = times;
      _isLoadingAvailability = false;
    });
  }

  String _serviceLabel(_ServiceOption option) {
    final l10n = AppLocalizations.of(context);
    final localizedServiceName = _localizedServiceName(option.name, l10n);
    if (option.price == null) return localizedServiceName;
    final isInt = option.price == option.price!.toInt();
    final priceText = isInt
        ? option.price!.toInt().toString()
        : option.price!.toStringAsFixed(2);
    return l10n.bookingServicePriceLabel(localizedServiceName, priceText);
  }

  String _localizedServiceName(String rawName, AppLocalizations l10n) {
    final normalized = rawName.trim().toLowerCase();
    switch (normalized) {
      case 'haircut':
      case 'حلاقة الرأس':
        return l10n.serviceHaircut;
      case 'beard trim':
      case 'لحية trim':
      case 'حلاقة الدقن':
        return l10n.barberDetailsFallbackServiceBeardTrim;
      case 'haircut + beard':
      case 'حلاقة الرأس والدقن':
        return l10n.barberProfileServiceHaircutAndBeard;
      case 'full head shave (zero cut)':
      case 'حلاقة كاملة':
      case 'حلاقة الرأس بالمكينة':
        return l10n.barberProfileServiceFullHeadShaveZeroCut;
      case 'beard machine shave':
      case 'حلاقة الدقن بالمكينة':
        return l10n.barberProfileServiceBeardMachineShave;
      case 'kids haircut':
      case 'أطفال حلاقة الرأس':
      case 'حلاقة أطفال':
        return l10n.barberProfileServiceKidsHaircut;
    }

    final replacements = <String, String>{
      'haircut': l10n.serviceHaircut,
      'beard': l10n.serviceBeard,
      'shave': l10n.serviceShave,
      'color': l10n.serviceColor,
      'kids': l10n.serviceKids,
    };

    var displayName = rawName;
    for (final entry in replacements.entries) {
      final pattern = RegExp(
        '\\b${RegExp.escape(entry.key)}\\b',
        caseSensitive: false,
      );
      displayName = displayName.replaceAllMapped(pattern, (_) => entry.value);
    }

    return displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _onConfirmBooking() async {
    final l10n = AppLocalizations.of(context);

    if (_isSubmitting) return;

    if (_selectedService == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookingSelectServiceError)));
      return;
    }

    if (_selectedTime == null || _selectedSlotStart == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookingSelectTimeError)));
      return;
    }

    final time = _selectedTime!;
    final slotStart = _selectedSlotStart!;

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

    try {
      final barberId = widget.barberId;
      await BookingStore(FirebaseFirestore.instance).createBooking(
        barberId: barberId,
        service: _selectedService!.name,
        slotStart: slotStart,
      );
    } on SlotAlreadyBookedException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookingSlotAlreadyBooked)));
      return;
    } on BarberUnavailableException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookingBarberOffline)));
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookingConfirmFailed)));
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
          service: _selectedService!.name,
          servicePrice: _selectedService!.price,
          selectedDate: slotStart,
          selectedTime: time,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: KloofColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: KloofColors.warmOffWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: KloofColors.primaryText),
        title: Text(l10n.bookingTitle),
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
                    const SizedBox(height: 8),
                    Text(
                      l10n.bookingSelectService,
                      style: TextStyle(
                        color: KloofColors.secondaryText,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingServices)
                      const Center(child: CircularProgressIndicator())
                    else if (_serviceOptions.isEmpty)
                      Text(
                        l10n.bookingNoServicesAvailable,
                        style: TextStyle(color: KloofColors.secondaryText),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _serviceOptions.map((service) {
                          final isSelected =
                              _selectedService?.name == service.name;
                          return ChoiceChip(
                            label: Text(
                              _serviceLabel(service),
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: isSelected,
                            onSelected: (_) => _selectService(service),
                            selectedColor: KloofColors.primaryBlack,
                            backgroundColor: KloofColors.cardBackground,
                            checkmarkColor: KloofColors.luxuryGold,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : KloofColors.primaryText,
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.bookingAvailableTimes,
                      style: TextStyle(
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
                        style: const TextStyle(
                          color: KloofColors.secondaryText,
                        ),
                      )
                    else if (_availableTimes.isEmpty)
                      Text(
                        l10n.bookingNoAvailableTimesToday,
                        style: const TextStyle(
                          color: KloofColors.secondaryText,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTimes.map((time) {
                          final isSelected = _selectedSlotStart == time.start;
                          return ChoiceChip(
                            label: Text(time.label),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedTime = time.label;
                                _selectedSlotStart = time.start;
                              });
                            },
                            selectedColor: KloofColors.primaryBlack,
                            backgroundColor: KloofColors.cardBackground,
                            checkmarkColor: KloofColors.luxuryGold,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : KloofColors.primaryText,
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
              color: KloofColors.warmOffWhite,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _onConfirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KloofColors.primaryBlack,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.bookingConfirmAction,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
  final int? duration;

  const _ServiceOption({
    required this.name,
    required this.price,
    required this.duration,
  });
}

class _BookingSlotOption {
  final String label;
  final DateTime start;

  const _BookingSlotOption({required this.label, required this.start});
}
