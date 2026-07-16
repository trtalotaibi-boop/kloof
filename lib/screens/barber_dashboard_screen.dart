import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BarberDashboardScreen extends StatefulWidget {
  final String barberName;

  const BarberDashboardScreen({
    super.key,
    required this.barberName,
  });

  @override
  State<BarberDashboardScreen> createState() => _BarberDashboardScreenState();
}

class _BarberDashboardScreenState extends State<BarberDashboardScreen> {
  bool _isOnline = false;
  bool _isSavingStatus = false;
  final List<String> _timeSlots = [
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
  ];
  final Map<String, bool> _slotEnabled = {};
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

          if (snapshot.docs.isEmpty) {
            _barberDocRef = FirebaseFirestore.instance.collection('barbers').doc(widget.barberName);
            setState(() {
              _slotEnabled.clear();
              for (final slot in _timeSlots) {
                _slotEnabled[slot] = true;
              }
              _isOnline = false;
            });
            return;
          }

          final barberDoc = snapshot.docs.first;
          _barberDocRef = barberDoc.reference;
          final data = barberDoc.data();
          final savedSlots = List<String>.from(data['availableSlots'] ?? []);
          final enabledSlots = savedSlots.whereType<String>().toSet();

          setState(() {
            _slotEnabled.clear();
            for (final slot in _timeSlots) {
              _slotEnabled[slot] = enabledSlots.contains(slot);
            }
            _isOnline = data['isOnline'] ?? false;
          });
        });
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() {
      _isSavingStatus = true;
    });

    try {
      final barberDocRef = _barberDocRef ??
          FirebaseFirestore.instance.collection('barbers').doc(widget.barberName);
      await barberDocRef.set(
        {'isOnline': value},
        SetOptions(merge: true),
      );
      if (mounted) {
        setState(() {
          _isOnline = value;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingStatus = false;
        });
      }
    }
  }

  Future<void> _toggleSlot(String slot, bool value) async {
    setState(() {
      _slotEnabled[slot] = value;
    });

    final barberDocRef = _barberDocRef ??
        FirebaseFirestore.instance.collection('barbers').doc(widget.barberName);

    if (value) {
      await barberDocRef.update({'availableSlots': FieldValue.arrayUnion([slot])});
    } else {
      await barberDocRef.update({'availableSlots': FieldValue.arrayRemove([slot])});
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
    final bookingData = bookingDoc.data();
    final time = bookingData?['time']?.toString();

    if (status == 'rejected' && time != null && _barberDocRef != null) {
      await _barberDocRef!.update({'availableSlots': FieldValue.arrayUnion([time])});
    }

    await bookingDoc.reference.update({'status': status});
  }

  @override
  void dispose() {
    _barberSubscription?.cancel();
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
        title: Text(
          widget.barberName,
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Availability',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Text(_isOnline ? 'Online' : 'Offline'),
                      const SizedBox(width: 8),
                      Switch(
                        value: _isOnline,
                        onChanged: _isSavingStatus ? null : _toggleOnlineStatus,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Working Hours',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: _timeSlots.map((slot) {
                    final isEnabled = _slotEnabled[slot] ?? true;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(slot),
                          Switch(
                            value: isEnabled,
                            onChanged: (value) => _toggleSlot(slot, value),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bookings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('barberName', isEqualTo: widget.barberName)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No bookings yet'));
                    }

                    return ListView(
                      children: snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status']?.toString() ?? 'pending';
                        final customerName = data['customerName']?.toString() ?? 'Customer';
                        final date = data['date']?.toString() ?? '-';
                        final time = data['time']?.toString() ?? '-';
                        final notes = data['notes']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      customerName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status == 'accepted'
                                            ? Colors.green.shade100
                                            : status == 'rejected'
                                                ? Colors.red.shade100
                                                : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Date: $date'),
                                Text('Time: $time'),
                                if (notes.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Notes: $notes'),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _updateBookingStatus(doc.id, 'accepted'),
                                        child: const Text('Accept'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _updateBookingStatus(doc.id, 'rejected'),
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
