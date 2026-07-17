import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/barber_repository_impl.dart';
import '../domain/usecases/toggle_online_status_usecase.dart';
import '../features/barber_status_cubit.dart';

class BarberDashboardScreen extends StatefulWidget {
  final String barberName;

  const BarberDashboardScreen({super.key, required this.barberName});

  @override
  State<BarberDashboardScreen> createState() => _BarberDashboardScreenState();
}

class _BarberDashboardScreenState extends State<BarberDashboardScreen> {
  static const List<String> _allDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  DocumentReference? _barberDocRef;
  String? _barberId;

  Set<String> _workingDays = _allDays.toSet();
  TimeOfDay _openingTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 23, minute: 0);
  int _appointmentDuration = 30;
  TimeOfDay? _breakStartTime;
  TimeOfDay? _breakEndTime;
  bool _isSavingWorkingHours = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _barberSubscription;

  late final BarberStatusCubit _barberStatusCubit;

  @override
  void initState() {
    super.initState();

    final repository = BarberRepositoryImpl(
      firestore: FirebaseFirestore.instance,
    );
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
            final docRef = FirebaseFirestore.instance
                .collection('barbers')
                .doc(widget.barberName);
            _barberDocRef = docRef;
            setState(() {
              _barberId = docRef.id;
              _workingDays = _allDays.toSet();
              _openingTime = const TimeOfDay(hour: 8, minute: 0);
              _closingTime = const TimeOfDay(hour: 23, minute: 0);
              _appointmentDuration = 30;
              _breakStartTime = null;
              _breakEndTime = null;
            });
            return;
          }

          final barberDoc = snapshot.docs.first;
          _barberDocRef = barberDoc.reference;
          final data = barberDoc.data();
          final workingHours = Map<String, dynamic>.from(
            data['workingHours'] ?? <String, dynamic>{},
          );

          final savedDays = List<String>.from(
            workingHours['workingDays'] ?? _allDays,
          ).where(_allDays.contains).toSet();
          final openingTime =
              _parseTimeLabel(workingHours['openingTime']?.toString()) ??
              const TimeOfDay(hour: 8, minute: 0);
          final closingTime =
              _parseTimeLabel(workingHours['closingTime']?.toString()) ??
              const TimeOfDay(hour: 23, minute: 0);
          final durationRaw = workingHours['appointmentDuration'];
          final duration = durationRaw is num ? durationRaw.toInt() : 30;
          final breakStart = _parseTimeLabel(
            workingHours['breakStart']?.toString(),
          );
          final breakEnd = _parseTimeLabel(
            workingHours['breakEnd']?.toString(),
          );

          setState(() {
            _barberId = barberDoc.id;
            _workingDays = savedDays.isEmpty ? _allDays.toSet() : savedDays;
            _openingTime = openingTime;
            _closingTime = closingTime;
            _appointmentDuration = [15, 30, 45, 60].contains(duration)
                ? duration
                : 30;
            _breakStartTime = breakStart;
            _breakEndTime = breakEnd;
          });
        });
  }

  TimeOfDay? _parseTimeLabel(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.trim().split(' ');
    if (parts.length != 2) return null;

    final hm = parts[0].split(':');
    if (hm.length != 2) return null;

    final rawHour = int.tryParse(hm[0]);
    final minute = int.tryParse(hm[1]);
    if (rawHour == null || minute == null) return null;

    var hour = rawHour;
    final period = parts[1].toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeLabel(TimeOfDay time) {
    final hour24 = time.hour;
    final minuteText = time.minute.toString().padLeft(2, '0');
    final isPm = hour24 >= 12;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minuteText ${isPm ? 'PM' : 'AM'}';
  }

  Future<void> _pickTime({
    required TimeOfDay initialTime,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      onPicked(picked);
    });
  }

  Future<void> _saveWorkingHours() async {
    final barberDocRef =
        _barberDocRef ??
        FirebaseFirestore.instance.collection('barbers').doc(widget.barberName);

    if (_workingDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one working day.'),
        ),
      );
      return;
    }

    final openingMinutes = (_openingTime.hour * 60) + _openingTime.minute;
    final closingMinutes = (_closingTime.hour * 60) + _closingTime.minute;
    if (closingMinutes <= openingMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Closing time must be after opening time.'),
        ),
      );
      return;
    }

    if (_breakStartTime != null && _breakEndTime != null) {
      final breakStartMinutes =
          (_breakStartTime!.hour * 60) + _breakStartTime!.minute;
      final breakEndMinutes =
          (_breakEndTime!.hour * 60) + _breakEndTime!.minute;
      if (breakEndMinutes <= breakStartMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Break end must be after break start.')),
        );
        return;
      }
      if (breakStartMinutes < openingMinutes ||
          breakEndMinutes > closingMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Break time must be within opening and closing hours.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSavingWorkingHours = true;
    });

    try {
      await barberDocRef.set({
        'workingHours': {
          'workingDays': _allDays.where(_workingDays.contains).toList(),
          'openingTime': _formatTimeLabel(_openingTime),
          'closingTime': _formatTimeLabel(_closingTime),
          'appointmentDuration': _appointmentDuration,
          'breakStart': _breakStartTime == null
              ? null
              : _formatTimeLabel(_breakStartTime!),
          'breakEnd': _breakEndTime == null
              ? null
              : _formatTimeLabel(_breakEndTime!),
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Working hours saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save working hours.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingWorkingHours = false;
        });
      }
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({'status': status});
  }

  Color _statusChipColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    final lower = status.toLowerCase();
    if (lower.isEmpty) return 'Pending';
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<String> _resolveCustomerName(
    String customerId,
    String? fallbackName,
  ) async {
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName;
    }
    if (customerId.trim().isEmpty) {
      return 'Customer';
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      final data = userDoc.data();
      final name = (data?['name'] ?? data?['fullName'] ?? data?['displayName'])
          ?.toString();
      if (name != null && name.trim().isNotEmpty) {
        return name;
      }
    } catch (_) {
      // Fall through to fallback.
    }

    return 'Customer';
  }

  @override
  void dispose() {
    _barberSubscription?.cancel();
    _barberStatusCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentBarberId = FirebaseAuth.instance.currentUser?.uid ?? _barberId;

    if (currentBarberId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.barberName)),
        body: const Center(child: Text('Barber is not signed in.')),
      );
    }

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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allDays.map((day) {
                          final isSelected = _workingDays.contains(day);
                          return FilterChip(
                            label: Text(day),
                            selected: isSelected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _workingDays.add(day);
                                } else {
                                  _workingDays.remove(day);
                                }
                              });
                            },
                            selectedColor: Colors.black,
                            backgroundColor: Colors.white,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Opening: ${_formatTimeLabel(_openingTime)}'),
                          OutlinedButton(
                            onPressed: () => _pickTime(
                              initialTime: _openingTime,
                              onPicked: (picked) => _openingTime = picked,
                            ),
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Closing: ${_formatTimeLabel(_closingTime)}'),
                          OutlinedButton(
                            onPressed: () => _pickTime(
                              initialTime: _closingTime,
                              onPicked: (picked) => _closingTime = picked,
                            ),
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _appointmentDuration,
                        items: const [15, 30, 45, 60]
                            .map(
                              (value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text('$value minutes'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _appointmentDuration = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Appointment Duration',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _breakStartTime == null
                                ? 'Break Start: Not set'
                                : 'Break Start: ${_formatTimeLabel(_breakStartTime!)}',
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _pickTime(
                                  initialTime: _breakStartTime ?? _openingTime,
                                  onPicked: (picked) =>
                                      _breakStartTime = picked,
                                ),
                                child: const Text('Set'),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: _breakStartTime == null
                                    ? null
                                    : () {
                                        setState(() {
                                          _breakStartTime = null;
                                        });
                                      },
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _breakEndTime == null
                                ? 'Break End: Not set'
                                : 'Break End: ${_formatTimeLabel(_breakEndTime!)}',
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _pickTime(
                                  initialTime: _breakEndTime ?? _closingTime,
                                  onPicked: (picked) => _breakEndTime = picked,
                                ),
                                child: const Text('Set'),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: _breakEndTime == null
                                    ? null
                                    : () {
                                        setState(() {
                                          _breakEndTime = null;
                                        });
                                      },
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSavingWorkingHours
                              ? null
                              : _saveWorkingHours,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSavingWorkingHours
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Working Hours'),
                        ),
                      ),
                    ],
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
                        .where('barberId', isEqualTo: currentBarberId)
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
                          final status =
                              data['status']?.toString() ?? 'pending';
                          final customerId =
                              data['customerId']?.toString() ?? '';
                          final customerName = data['customerName']?.toString();
                          final service = data['service']?.toString() ?? '-';
                          final date = _formatDate(
                            data['bookingDate'] as Timestamp?,
                          );
                          final time = data['selectedTime']?.toString() ?? '-';

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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: FutureBuilder<String>(
                                          future: _resolveCustomerName(
                                            customerId,
                                            customerName,
                                          ),
                                          builder: (context, nameSnapshot) {
                                            final displayName =
                                                nameSnapshot.data ?? 'Customer';
                                            return Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusChipColor(
                                            status,
                                          ).withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: _statusChipColor(status),
                                          ),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _statusChipColor(status),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Service: $service'),
                                  Text('Date: $date'),
                                  Text('Time: $time'),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateBookingStatus(
                                            doc.id,
                                            'accepted',
                                          ),
                                          child: const Text('Accept'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateBookingStatus(
                                            doc.id,
                                            'rejected',
                                          ),
                                          child: const Text('Reject'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateBookingStatus(
                                            doc.id,
                                            'completed',
                                          ),
                                          child: const Text('Complete'),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
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
              onChanged: (_) => context.read<BarberStatusCubit>().toggleOnline(
                barberId,
                state.isOnline,
              ),
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
