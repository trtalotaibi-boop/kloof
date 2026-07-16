import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      await FirebaseFirestore.instance.collection('bookings').add({
        'barberName': widget.barberName,
        'customerName': 'Customer',
        'service': widget.service,
        'date': _selectedDate.toIso8601String(),
        'time': _selectedTime,
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_barberDocRef != null) {
        await _barberDocRef!.update({'availableSlots': FieldValue.arrayRemove([_selectedTime])});
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking Confirmed')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save booking: $e')),
      );
    } finally {
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
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _timeSlots.map((time) {
                    final isAvailable = _availableSlots.contains(time);
                    final isSelected = time == _selectedTime;
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
                      backgroundColor: isAvailable ? null : Colors.grey.shade300,
                      disabledColor: Colors.grey.shade300,
                      labelStyle: TextStyle(
                        color: isAvailable
                            ? (isSelected ? Colors.white : Colors.black)
                            : Colors.grey.shade700,
                      ),
                    );
                  }).toList(),
                ),
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
