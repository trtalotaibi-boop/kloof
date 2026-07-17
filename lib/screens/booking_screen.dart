import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  int _toMinutes(String time) {
    final parts = time.split(' ');
    final hm = parts.first.split(':');
    var hour = int.parse(hm[0]);
    final minute = int.parse(hm[1]);
    final period = parts.last.toUpperCase();

    if (period == 'PM' && hour != 12) {
      hour += 12;
    }
    if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return (hour * 60) + minute;
  }

  String _toTimeLabel(int totalMinutes) {
    final hour24 = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    final isPm = hour24 >= 12;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minuteText = minute.toString().padLeft(2, '0');
    final period = isPm ? 'PM' : 'AM';
    return '$hour12:$minuteText $period';
  }

  String _todayLabel() {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[DateTime.now().weekday - 1];
  }

  List<String> _buildSlots({
    required String openingTime,
    required String closingTime,
    required int duration,
    String? breakStart,
    String? breakEnd,
    required bool hidePast,
  }) {
    final slots = <String>[];

    final openingMinutes = _toMinutes(openingTime);
    final closingMinutes = _toMinutes(closingTime);
    if (closingMinutes <= openingMinutes) return slots;

    final breakStartMinutes = breakStart == null || breakStart.trim().isEmpty
        ? null
        : _toMinutes(breakStart);
    final breakEndMinutes = breakEnd == null || breakEnd.trim().isEmpty
        ? null
        : _toMinutes(breakEnd);

    var nowMinutes = 0;
    if (hidePast) {
      final now = DateTime.now();
      nowMinutes = (now.hour * 60) + now.minute;
    }

    for (
      var start = openingMinutes;
      start + duration <= closingMinutes;
      start += duration
    ) {
      final end = start + duration;
      if (hidePast && start <= nowMinutes) {
        continue;
      }

      final overlapsBreak =
          breakStartMinutes != null &&
          breakEndMinutes != null &&
          start < breakEndMinutes &&
          end > breakStartMinutes;
      if (overlapsBreak) {
        continue;
      }

      slots.add(_toTimeLabel(start));
    }

    return slots;
  }

  Future<void> _onConfirmBooking() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot before confirming.'),
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
          const SnackBar(content: Text('Barber not found. Please try again.')),
        );
        return;
      }

      final barberId = barberSnapshot.docs.first.id;
      final barberData = barberSnapshot.docs.first.data();
      final isOnline = barberData['isOnline'] == true;
      final workingHours = Map<String, dynamic>.from(
        barberData['workingHours'] ?? <String, dynamic>{},
      );
      final workingDays = List<String>.from(workingHours['workingDays'] ?? []);
      final todayWorking = workingDays.contains(_todayLabel());

      if (!isOnline || !todayWorking) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barber is unavailable today.')),
        );
        return;
      }

      final openingTime = workingHours['openingTime']?.toString() ?? '8:00 AM';
      final closingTime = workingHours['closingTime']?.toString() ?? '11:00 PM';
      final duration = (workingHours['appointmentDuration'] is num)
          ? (workingHours['appointmentDuration'] as num).toInt()
          : 30;
      final safeDuration = [15, 30, 45, 60].contains(duration) ? duration : 30;
      final breakStart = workingHours['breakStart']?.toString();
      final breakEnd = workingHours['breakEnd']?.toString();

      final availableSlots = _buildSlots(
        openingTime: openingTime,
        closingTime: closingTime,
        duration: safeDuration,
        breakStart: breakStart,
        breakEnd: breakEnd,
        hidePast: true,
      );

      if (!availableSlots.contains(time)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a valid available time slot.'),
          ),
        );
        return;
      }

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

      await FirebaseFirestore.instance.collection('bookings').add({
        'barberId': barberId,
        'barberName': widget.barberName,
        'customerId': customerId,
        'service': widget.service,
        'selectedTime': time,
        'bookingDate': Timestamp.fromDate(bookingDate),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to confirm booking.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingConfirmationScreen(
          barberName: widget.barberName,
          service: widget.service,
          selectedDate: DateTime.now(),
          selectedTime: time,
        ),
      ),
    );
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
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('barbers')
                      .where('name', isEqualTo: widget.barberName)
                      .limit(1)
                      .snapshots(),
                  builder: (context, barberSnapshot) {
                    if (barberSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!barberSnapshot.hasData ||
                        barberSnapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Barber is unavailable today.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    final barberDoc = barberSnapshot.data!.docs.first;
                    final barberId = barberDoc.id;
                    final barberData = barberDoc.data();
                    final isOnline = barberData['isOnline'] == true;
                    final workingHours = Map<String, dynamic>.from(
                      barberData['workingHours'] ?? <String, dynamic>{},
                    );
                    final workingDays = List<String>.from(
                      workingHours['workingDays'] ?? [],
                    );
                    final todayWorking = workingDays.contains(_todayLabel());
                    final openingTime =
                        workingHours['openingTime']?.toString() ?? '8:00 AM';
                    final closingTime =
                        workingHours['closingTime']?.toString() ?? '11:00 PM';
                    final duration =
                        (workingHours['appointmentDuration'] is num)
                        ? (workingHours['appointmentDuration'] as num).toInt()
                        : 30;
                    final safeDuration = [15, 30, 45, 60].contains(duration)
                        ? duration
                        : 30;
                    final breakStart = workingHours['breakStart']?.toString();
                    final breakEnd = workingHours['breakEnd']?.toString();

                    final slots = _buildSlots(
                      openingTime: openingTime,
                      closingTime: closingTime,
                      duration: safeDuration,
                      breakStart: breakStart,
                      breakEnd: breakEnd,
                      hidePast: true,
                    );

                    final now = DateTime.now();
                    final bookingDate = DateTime(now.year, now.month, now.day);

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('bookings')
                          .where('barberId', isEqualTo: barberId)
                          .where(
                            'bookingDate',
                            isEqualTo: Timestamp.fromDate(bookingDate),
                          )
                          .snapshots(),
                      builder: (context, bookingSnapshot) {
                        final bookedSlots = bookingSnapshot.data == null
                            ? <String>{}
                            : bookingSnapshot.data!.docs
                                  .where(
                                    (doc) =>
                                        (doc.data()['status']?.toString() ??
                                            'pending') !=
                                        'rejected',
                                  )
                                  .map(
                                    (doc) =>
                                        doc
                                            .data()['selectedTime']
                                            ?.toString() ??
                                        '',
                                  )
                                  .where((slot) => slot.isNotEmpty)
                                  .toSet();

                        if (_selectedTime != null &&
                            (!slots.contains(_selectedTime) ||
                                bookedSlots.contains(_selectedTime))) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() {
                              _selectedTime = null;
                            });
                          });
                        }

                        return ListView(
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
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Time',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (!isOnline || !todayWorking) ...[
                              const SizedBox(height: 20),
                              const Center(
                                child: Text(
                                  'Barber is unavailable today.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Online now',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Available until $closingTime',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: slots.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      mainAxisExtent: 34,
                                    ),
                                itemBuilder: (context, index) {
                                  final time = slots[index];
                                  final isSelected = time == _selectedTime;
                                  final isBooked = bookedSlots.contains(time);

                                  return InkWell(
                                    onTap: isBooked
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedTime = time;
                                            });
                                          },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isBooked
                                            ? Colors.grey.shade300
                                            : (isSelected
                                                  ? Colors.black
                                                  : Colors.white),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isBooked
                                              ? Colors.grey.shade400
                                              : (isSelected
                                                    ? Colors.black
                                                    : Colors.black26),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        time,
                                        style: TextStyle(
                                          color: isBooked
                                              ? Colors.grey.shade600
                                              : (isSelected
                                                    ? Colors.white
                                                    : Colors.black),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
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
