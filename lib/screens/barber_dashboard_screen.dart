import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kloof/l10n/app_localizations.dart';

import '../data/repositories/barber_repository_impl.dart';
import '../domain/usecases/toggle_online_status_usecase.dart';
import '../features/barber_status_cubit.dart';
import 'barber_bookings_screen.dart';
import 'barber_profile_screen.dart';
import 'welcome_screen.dart';

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
  bool _isCheckingRole = true;
  bool _isRoleAllowed = false;

  @override
  void initState() {
    super.initState();

    final repository = BarberRepositoryImpl(
      firestore: FirebaseFirestore.instance,
    );
    final useCase = ToggleOnlineStatusUseCase(repository);
    _barberStatusCubit = BarberStatusCubit(useCase);

    _enforceBarberAccess();
  }

  Future<void> _enforceBarberAccess() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final role =
          (userDoc.data()?['role']?.toString().toLowerCase() ?? 'customer');

      if (role != 'barber') {
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      _listenToBarberUpdates();
      if (!mounted) return;
      setState(() {
        _isRoleAllowed = true;
        _isCheckingRole = false;
      });
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
    }
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
    final l10n = AppLocalizations.of(context);
    final barberDocRef =
        _barberDocRef ??
        FirebaseFirestore.instance.collection('barbers').doc(widget.barberName);

    if (_workingDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.barberDashboardSelectWorkingDayError),
        ),
      );
      return;
    }

    final openingMinutes = (_openingTime.hour * 60) + _openingTime.minute;
    final closingMinutes = (_closingTime.hour * 60) + _closingTime.minute;
    if (closingMinutes <= openingMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.barberDashboardClosingAfterOpeningError),
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
          SnackBar(
            content: Text(l10n.barberDashboardBreakEndAfterStartError),
          ),
        );
        return;
      }
      if (breakStartMinutes < openingMinutes ||
          breakEndMinutes > closingMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.barberDashboardBreakWithinHoursError),
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
      ).showSnackBar(SnackBar(content: Text(l10n.barberDashboardSaved)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.barberDashboardSaveFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingWorkingHours = false;
        });
      }
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

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    final bookingRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId);

    final bookingSnapshot = await bookingRef.get();
    final bookingData = bookingSnapshot.data();
    final customerId = bookingData?['customerId']?.toString();

    await bookingRef.update({'status': status});

    if (customerId == null || customerId.trim().isEmpty) {
      return;
    }

    String? message;
    if (status == 'accepted') {
      message = 'Your booking has been accepted.';
    } else if (status == 'rejected') {
      message = 'Your booking has been rejected.';
    } else if (status == 'completed') {
      message = 'Your appointment has been completed.';
    }

    if (message != null) {
      await _createNotification(
        recipientId: customerId,
        message: message,
        bookingId: bookingId,
      );
    }
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final shouldSignOut =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(l10n.homeSignOutTitle),
              content: Text(l10n.homeSignOutConfirm),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.homeSignOutAction),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldSignOut) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
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

  String _statusLabel(String status, AppLocalizations l10n) {
    final lower = status.toLowerCase();
    switch (lower) {
      case 'accepted':
        return l10n.myBookingsStatusAccepted;
      case 'rejected':
        return l10n.myBookingsStatusRejected;
      case 'completed':
        return l10n.myBookingsStatusCompleted;
      case 'pending':
      default:
        return l10n.myBookingsStatusPending;
    }
  }

  String _formatDate(Timestamp? timestamp, AppLocalizations l10n) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat.yMd(l10n.localeName).format(date);
  }

  String _formatDisplayTime(BuildContext context, TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  String _localizedDayLabel(String day, AppLocalizations l10n) {
    switch (day) {
      case 'Mon':
        return l10n.barberDashboardDayMon;
      case 'Tue':
        return l10n.barberDashboardDayTue;
      case 'Wed':
        return l10n.barberDashboardDayWed;
      case 'Thu':
        return l10n.barberDashboardDayThu;
      case 'Fri':
        return l10n.barberDashboardDayFri;
      case 'Sat':
        return l10n.barberDashboardDaySat;
      case 'Sun':
        return l10n.barberDashboardDaySun;
      default:
        return day;
    }
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

  Future<String> _resolveCustomerName(
    String customerId,
    String? fallbackName,
    AppLocalizations l10n,
  ) async {
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName;
    }
    if (customerId.trim().isEmpty) {
      return l10n.barberBookingsCustomerFallback;
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

    return l10n.barberBookingsCustomerFallback;
  }

  @override
  void dispose() {
    _barberSubscription?.cancel();
    _barberStatusCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isCheckingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isRoleAllowed) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final currentBarberId = FirebaseAuth.instance.currentUser?.uid ?? _barberId;

    if (currentBarberId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.barberName)),
        body: Center(child: Text(l10n.barberBookingsSignedOut)),
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
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(
            widget.barberName,
            style: const TextStyle(color: Colors.black),
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BarberProfileScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.person_outline, color: Colors.black),
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.black),
            ),
          ],
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
                    Text(
                      l10n.barberDashboardAvailability,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _OnlineStatusToggle(barberId: _barberId!),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.barberDashboardWorkingHours,
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
                            label: Text(_localizedDayLabel(day, l10n)),
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
                          Text(
                            l10n.myBookingsValueRow(
                              l10n.barberDashboardOpening,
                              _formatDisplayTime(context, _openingTime),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _pickTime(
                              initialTime: _openingTime,
                              onPicked: (picked) => _openingTime = picked,
                            ),
                            child: Text(l10n.barberDashboardSet),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.myBookingsValueRow(
                              l10n.barberDashboardClosing,
                              _formatDisplayTime(context, _closingTime),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _pickTime(
                              initialTime: _closingTime,
                              onPicked: (picked) => _closingTime = picked,
                            ),
                            child: Text(l10n.barberDashboardSet),
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
                                child: Text(
                                  l10n.barberProfileDurationMinutes(
                                    value.toString(),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _appointmentDuration = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: l10n.barberDashboardAppointmentDuration,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _breakStartTime == null
                                ? l10n.myBookingsValueRow(
                                    l10n.barberDashboardBreakStart,
                                    l10n.barberDashboardNotSet,
                                  )
                                : l10n.myBookingsValueRow(
                                    l10n.barberDashboardBreakStart,
                                    _formatDisplayTime(
                                      context,
                                      _breakStartTime!,
                                    ),
                                  ),
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _pickTime(
                                  initialTime: _breakStartTime ?? _openingTime,
                                  onPicked: (picked) =>
                                      _breakStartTime = picked,
                                ),
                                child: Text(l10n.barberDashboardSet),
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
                                child: Text(l10n.barberDashboardClear),
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
                                ? l10n.myBookingsValueRow(
                                    l10n.barberDashboardBreakEnd,
                                    l10n.barberDashboardNotSet,
                                  )
                                : l10n.myBookingsValueRow(
                                    l10n.barberDashboardBreakEnd,
                                    _formatDisplayTime(context, _breakEndTime!),
                                  ),
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _pickTime(
                                  initialTime: _breakEndTime ?? _closingTime,
                                  onPicked: (picked) => _breakEndTime = picked,
                                ),
                                child: Text(l10n.barberDashboardSet),
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
                                child: Text(l10n.barberDashboardClear),
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
                                : Text(l10n.barberDashboardSaveWorkingHours),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BarberBookingsScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.barberBookingsTitle),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.barberDashboardBookings,
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
                        return Center(child: Text(l10n.barberDashboardNoBookings));
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
                          final localizedService =
                              _localizedServiceName(service, l10n);
                          final date = _formatDate(
                            data['bookingDate'] as Timestamp?,
                            l10n,
                          );
                          final time = data['selectedTime']?.toString() ?? '-';

                          return Card(
                            margin: const EdgeInsetsDirectional.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.all(14),
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
                                            l10n,
                                          ),
                                          builder: (context, nameSnapshot) {
                                            final displayName =
                                                nameSnapshot.data ??
                                                l10n.barberBookingsCustomerFallback;
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
                                          _statusLabel(status, l10n),
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
                                  Text(
                                    l10n.myBookingsValueRow(
                                      l10n.myBookingsServiceLabel,
                                      localizedService,
                                    ),
                                  ),
                                  Text(
                                    l10n.myBookingsValueRow(
                                      l10n.myBookingsDateLabel,
                                      date,
                                    ),
                                  ),
                                  Text(
                                    l10n.myBookingsValueRow(
                                      l10n.myBookingsTimeLabel,
                                      time,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateBookingStatus(
                                            doc.id,
                                            'accepted',
                                          ),
                                          child: Text(l10n.barberBookingsAccept),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateBookingStatus(
                                            doc.id,
                                            'rejected',
                                          ),
                                          child: Text(l10n.barberBookingsReject),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateBookingStatus(
                                            doc.id,
                                            'completed',
                                          ),
                                          child: Text(l10n.barberDashboardComplete),
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
    final l10n = AppLocalizations.of(context);

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
            Text(state.isOnline ? l10n.barberDashboardOnline : l10n.homeOfflineStatus),
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
