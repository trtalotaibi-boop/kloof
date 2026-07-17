import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/barber_repository_impl.dart';
import '../domain/usecases/toggle_online_status_usecase.dart';
import '../features/barber_status_cubit.dart';

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
  String? _barberId;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _barberSubscription;

  late final BarberStatusCubit _barberStatusCubit;

  @override
  void initState() {
    super.initState();

    final repository = BarberRepositoryImpl(firestore: FirebaseFirestore.instance);
    final useCase = ToggleOnlineStatusUseCase(repository);
    _barberStatusCubit = BarberStatusCubit(useCase);

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
        final docRef =
            FirebaseFirestore.instance.collection('barbers').doc(widget.barberName);
        _barberDocRef = docRef;
        setState(() {
          _barberId = docRef.id;
          _slotEnabled
            ..clear()
            ..addEntries(_timeSlots.map((slot) => MapEntry(slot, true)));
        });
        return;
      }

      final barberDoc = snapshot.docs.first;
      _barberDocRef = barberDoc.reference;
      final data = barberDoc.data();
      final savedSlots = List<String>.from(data['availableSlots'] ?? []);
      final enabledSlots = savedSlots.whereType<String>().toSet();

      setState(() {
        _barberId = barberDoc.id;
        _slotEnabled
          ..clear()
          ..addEntries(
            _timeSlots.map((slot) => MapEntry(slot, enabledSlots.contains(slot))),
          );
      });
    });
  }

  Future<void> _toggleSlot(String slot, bool value) async {
    setState(() => _slotEnabled[slot] = value);

    final barberDocRef = _barberDocRef ??
        FirebaseFirestore.instance.collection('barbers').doc(widget.barberName);

    await barberDocRef.update({
      'availableSlots': value
          ? FieldValue.arrayUnion([slot])
          : FieldValue.arrayRemove([slot]),
    });
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    final bookingDoc =
        await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
    final bookingData = bookingDoc.data();
    final time = bookingData?['selectedTime']?.toString();

    if (status == 'Rejected' && time != null && _barberDocRef != null) {
      await _barberDocRef!.update({
        'availableSlots': FieldValue.arrayUnion([time]),
      });
    }

    await bookingDoc.reference.update({'bookingStatus': status});
  }

  @override
  void dispose() {
    _barberSubscription?.cancel();
    _barberStatusCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_barberId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.barberName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return BlocProvider<BarberStatusCubit>.value(
      value: _barberStatusCubit,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(widget.barberName, style: const TextStyle(color: Colors.black)),
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
                    _OnlineStatusToggle(barberId: _barberId!),
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
                          final status = data['bookingStatus']?.toString() ?? 'Pending';
                          final customerName =
                              data['customerName']?.toString() ?? 'Customer';
                          final date = data['selectedDate']?.toString() ?? '-';
                          final time = data['selectedTime']?.toString() ?? '-';
                          final services =
                              List<String>.from(data['selectedServices'] ?? []);
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: status == 'Accepted'
                                              ? Colors.green.shade100
                                              : status == 'Rejected'
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
                                  if (services.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text('Services: ${services.join(", ")}'),
                                  ],
                                  if (notes.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text('Notes: $notes'),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _updateBookingStatus(doc.id, 'Accepted'),
                                          child: const Text('Accept'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _updateBookingStatus(doc.id, 'Rejected'),
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
      ),
    );
  }
}

/// Isolated so a debounced Firestore write / Cubit state change only
/// rebuilds this Row, not the entire dashboard (bookings list, working
/// hours grid, etc).
class _OnlineStatusToggle extends StatelessWidget {
  final String barberId;
  const _OnlineStatusToggle({required this.barberId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BarberStatusCubit, BarberStatusState>(
      listener: (context, state) {
        if (state is BarberStatusError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final isUpdating = state is BarberStatusUpdating;
        return Row(
          children: [
            Text(state.isOnline ? 'Online' : 'Offline'),
            const SizedBox(width: 8),
            Switch(
              value: state.isOnline,
              onChanged: (_) => context
                  .read<BarberStatusCubit>()
                  .toggleOnline(barberId, state.isOnline),
            ),
            if (isUpdating)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        );
      },
    );
  }
}