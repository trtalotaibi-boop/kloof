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
  String? _selectedService;
  String? _selectedTime;

  List<String> _serviceNames() {
    return widget.service
        .replaceAll('•', ',')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
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
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service before confirming.'),
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot before confirming.'),
        ),
      );
      return;
    }

    final service = _selectedService!;
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

    try {
      final now = DateTime.now();
      final bookingDate = DateTime(now.year, now.month, now.day);

      final barberId = widget.barberId;

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
          const SnackBar(
            content: Text('This slot is already booked for today.'),
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
            'service': service,
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
        const SnackBar(content: Text('Failed to confirm booking.')),
      );
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingConfirmationScreen(
          barberName: widget.barberName,
          service: service,
          selectedDate: DateTime.now(),
          selectedTime: time,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = _serviceNames();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Book Appointment',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ListView(
                  children: [
                    Text(
                      widget.barberName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Select Service',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (services.isEmpty)
                      const Text(
                        'No services available.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: services.map((service) {
                          final selected = _selectedService == service;
                          return ChoiceChip(
                            label: Text(_localizedServiceName(service, l10n)),
                            selected: selected,
                            onSelected: (_) {
                              setState(() {
                                _selectedService = service;
                              });
                            },
                            selectedColor: Colors.black,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.black,
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
                    const Text(
                      'Select Time',
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
                              ? 'Select Time'
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onConfirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Confirm Booking',
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
