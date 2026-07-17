import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'booking_success_screen.dart';

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
  DateTime _selectedDate = DateTime.now();
  String _selectedTime = '09:00';
  final List<String> _timeSlots = [
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
  ];
  final List<String> _availableSlots = [];
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  bool _isLoadingSlots = true;
  DocumentReference? _barberDocRef;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _barberSubscription;

  @override
  void initState() {
    super.initState();
    _listenToBarberUpdates();
  }

  void _listenToBarberUpdates() {
    _barberSubscription?.cancel();

    _barberSubscription = FirebaseFirestore.instance
        .collection('barbers')
        .where('name', isEqualTo: widget.barberName)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          setState(() {
            _isLoadingSlots = false;
          });

          if (snapshot.docs.isEmpty) {
            _barberDocRef = null;
            setState(() {
              _availableSlots
                ..clear()
                ..addAll(_timeSlots);
            });
            return;
          }

          final barberDoc = snapshot.docs.first;
          _barberDocRef = barberDoc.reference;
          final data = barberDoc.data();
          final savedSlots = List<String>.from(data['availableSlots'] ?? []);
          final enabledSlots = savedSlots.whereType<String>().toSet();

          setState(() {
            _availableSlots
              ..clear()
              ..addAll(_timeSlots.where(enabledSlots.contains));
            if (_availableSlots.isNotEmpty && !_availableSlots.contains(_selectedTime)) {
              _selectedTime = _availableSlots.first;
            }
          });
        });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _getSlotLabel() {
    return _isToday(_selectedDate) ? 'Available Today' : 'Available for Selected Date';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedTime.isEmpty || !_availableSlots.contains(_selectedTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This time slot is currently unavailable.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Check for double-booking: verify no booking exists for this barber, date, and time
      final existingBookings = await FirebaseFirestore.instance
          .collection('bookings')
          .where('barberName', isEqualTo: widget.barberName)
          .where('selectedDate', isEqualTo: _selectedDate.toIso8601String())
          .where('selectedTime', isEqualTo: _selectedTime)
          .limit(1)
          .get();

      if (existingBookings.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This time slot is no longer available.')),
        );
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
        return;
      }

      // Create booking document
      final bookingDoc = await FirebaseFirestore.instance.collection('bookings').add({
        'bookingId': '', // Will be set to doc ID below
        'customerId': 'customer_001', // Placeholder - would come from auth in real app
        'barberId': '', // Will be queried from barber document
        'barberName': widget.barberName,
        'selectedDate': _selectedDate.toIso8601String(),
        'selectedTime': _selectedTime,
        'selectedServices': [widget.service],
        'notes': _notesController.text.trim(),
        'totalPrice': 0.0, // Placeholder - would calculate based on services
        'paymentMethod': 'Cash',
        'bookingStatus': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update with bookingId
      await bookingDoc.update({'bookingId': bookingDoc.id});

      // Get barberId from barber document
      if (_barberDocRef != null) {
        final barberSnapshot = await _barberDocRef!.get();
        final barberId = barberSnapshot.id;
        await bookingDoc.update({'barberId': barberId});
        
        // Remove booked time from availability
        await _barberDocRef!.update({'availableSlots': FieldValue.arrayRemove([_selectedTime])});
      }

      if (!mounted) return;

      // Navigate to success screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BookingSuccessScreen(
            barberName: widget.barberName,
            selectedDate: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            selectedTime: _selectedTime,
            selectedService: widget.service,
            notes: _notesController.text.trim(),
            bookingId: bookingDoc.id,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save booking: $e')),
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _barberSubscription?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 8),
              Text(
                'Service: ${widget.service}',
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 24),
              const Text(
                'Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_isLoadingSlots)
                const Center(child: CircularProgressIndicator())
              else ...[
                Text(
                  _getSlotLabel(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _timeSlots.map((time) {
                    final isAvailable = _availableSlots.contains(time);
                    final isSelected = time == _selectedTime;
                    final isToday = _isToday(_selectedDate);
                    
                    Color getBackgroundColor() {
                      if (!isAvailable) {
                        return Colors.grey.shade300;
                      }
                      if (isToday) {
                        return Colors.green.shade100;
                      }
                      return Colors.orange.shade100;
                    }

                    Color getLabelColor() {
                      if (!isAvailable) {
                        return Colors.grey.shade700;
                      }
                      if (isSelected) {
                        return Colors.white;
                      }
                      return Colors.black;
                    }

                    return ChoiceChip(
                      label: Text(time),
                      selected: isSelected,
                      onSelected: isAvailable && !_isSaving
                          ? (_) {
                              setState(() {
                                _selectedTime = time;
                              });
                            }
                          : null,
                      selectedColor: Colors.black,
                      backgroundColor: getBackgroundColor(),
                      disabledColor: Colors.grey.shade300,
                      labelStyle: TextStyle(
                        color: getLabelColor(),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Notes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Optional notes...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Confirm Booking'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
