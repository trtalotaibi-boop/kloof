import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kloof/l10n/app_localizations.dart';

import 'booking_confirmation_screen.dart';
import 'login_screen.dart';

class BookingScreen extends StatefulWidget {
  final String barberName;
  final String service;

  const BookingScreen({
    super.key,
    required this.barberName,
    required this.service,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String? _selectedTime;
  bool _isLoadingServices = true;
  bool _isSubmitting = false;
  List<_ServiceOption> _serviceOptions = [];
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
      final barberSnapshot = await FirebaseFirestore.instance
          .collection('barbers')
          .where('name', isEqualTo: widget.barberName)
          .limit(1)
          .get();

      final options = <_ServiceOption>[];
      final seenNames = <String>{};
      if (barberSnapshot.docs.isNotEmpty) {
        final data = barberSnapshot.docs.first.data();
        final rawServices = data['services'];

        if (rawServices is List) {
          for (final item in rawServices) {
            if (item is Map<String, dynamic>) {
              final priceRaw = item['price'];
              final price = priceRaw is num
                  ? priceRaw.toDouble()
                  : double.tryParse(priceRaw?.toString() ?? '');
              final names = _splitServiceNames(
                (item['name'] ?? '').toString().trim(),
              );
              for (final name in names) {
                final key = name.toLowerCase();
                if (seenNames.contains(key)) continue;
                seenNames.add(key);
                options.add(_ServiceOption(name: name, price: price));
              }
              continue;
            }

            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final priceRaw = map['price'];
              final price = priceRaw is num
                  ? priceRaw.toDouble()
                  : double.tryParse(priceRaw?.toString() ?? '');
              final names = _splitServiceNames(
                (map['name'] ?? '').toString().trim(),
              );
              for (final name in names) {
                final key = name.toLowerCase();
                if (seenNames.contains(key)) continue;
                seenNames.add(key);
                options.add(_ServiceOption(name: name, price: price));
              }
              continue;
            }

            final names = _splitServiceNames(item.toString().trim());
            for (final name in names) {
              final key = name.toLowerCase();
              if (seenNames.contains(key)) continue;
              seenNames.add(key);
              options.add(_ServiceOption(name: name, price: null));
            }
          }
        }
      }

      if (options.isEmpty) {
        final fallback = _splitServiceNames(widget.service);
        for (final name in fallback) {
          options.add(_ServiceOption(name: name, price: null));
        }
      }

      if (!mounted) return;
      setState(() {
        _serviceOptions = options;
        _selectedService = options.isNotEmpty ? options.first : null;
        _isLoadingServices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingServices = false;
      });
    }
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

    return displayName;
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

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedTime = picked.format(context);
    });
  }

  Future<void> _onConfirmBooking() async {
    final l10n = AppLocalizations.of(context);

    if (_isSubmitting) return;

    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.bookingSelectServiceError),
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.bookingSelectTimeError),
        ),
      );
      return;
    }

    final time = _selectedTime!;

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
      final now = DateTime.now();
      final bookingDate = DateTime(now.year, now.month, now.day);

      final barberSnapshot = await FirebaseFirestore.instance
          .collection('barbers')
          .where('name', isEqualTo: widget.barberName)
          .limit(1)
          .get();

      if (barberSnapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookingBarberNotFound)),
        );
        return;
      }

      final barberId = barberSnapshot.docs.first.id;

      final existingSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('barberId', isEqualTo: barberId)
          .where('bookingDate', isEqualTo: Timestamp.fromDate(bookingDate))
          .limit(100)
          .get();

      final bookedSlots = existingSnapshot.docs
          .where(
            (doc) =>
                (doc.data()['status']?.toString() ?? 'pending') != 'rejected',
          )
          .map((doc) => doc.data()['selectedTime']?.toString() ?? '')
          .where((slot) => slot.isNotEmpty)
          .toSet();

      if (bookedSlots.contains(time)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.bookingSlotAlreadyBooked),
          ),
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
            'service': _selectedService!.name,
            'servicePrice': _selectedService!.price,
            'selectedTime': time,
            'bookingDate': Timestamp.fromDate(bookingDate),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

      await _createNotification(
        recipientId: customerId,
        message: 'Your booking request has been submitted.',
        bookingId: bookingRef.id,
      );

      await _createNotification(
        recipientId: barberId,
        message: 'New booking request.',
        bookingId: bookingRef.id,
      );
    } catch (e) {
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
          service: _selectedService!.name,
          servicePrice: _selectedService!.price,
          selectedDate: DateTime.now(),
          selectedTime: time,
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
          style: TextStyle(color: Colors.black),
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
                    const SizedBox(height: 8),
                    Text(
                      l10n.bookingSelectService,
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingServices)
                      const Center(child: CircularProgressIndicator())
                    else if (_serviceOptions.isEmpty)
                      Text(
                        l10n.bookingNoServicesAvailable,
                        style: TextStyle(color: Colors.black54),
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
                            onSelected: (_) {
                              setState(() {
                                _selectedService = service;
                              });
                            },
                            selectedColor: Colors.black,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.bookingSelectTime,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _pickTime,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black26),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _selectedTime == null
                              ? l10n.bookingSelectTime
                              : _selectedTime!,
                        ),
                      ),
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

  const _ServiceOption({required this.name, required this.price});
}
