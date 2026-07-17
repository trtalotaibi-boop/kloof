import 'package:flutter/material.dart';

import 'booking_confirmation_screen.dart';

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
  static const int _dayStartMinutes = 8 * 60;
  static const int _dayEndMinutes = 23 * 60;

  final bool _isOnline = true;
  final String _openingTime = '8:00 AM';
  final String _closingTime = '11:00 PM';
  final List<String> _bookedSlots = ['10:00 AM', '2:30 PM', '6:00 PM'];

  String? _selectedTime;
  late final List<String> _timeSlots = _generateTimeSlots();

  List<String> _generateTimeSlots() {
    final slots = <String>[];
    final startMinutes = _toMinutes(
      _openingTime,
    ).clamp(_dayStartMinutes, _dayEndMinutes);
    final endMinutes = _toMinutes(
      _closingTime,
    ).clamp(_dayStartMinutes, _dayEndMinutes);

    if (endMinutes < startMinutes) {
      return slots;
    }

    for (var minutes = startMinutes; minutes <= endMinutes; minutes += 30) {
      if (minutes < _dayStartMinutes || minutes > _dayEndMinutes) {
        continue;
      }
      slots.add(_toTimeLabel(minutes));
    }

    return slots;
  }

  bool _isWithinWorkingRange(String timeLabel) {
    final minutes = _toMinutes(timeLabel);
    return minutes >= _dayStartMinutes && minutes <= _dayEndMinutes;
  }

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

  void _onConfirmBooking() {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot before confirming.'),
        ),
      );
      return;
    }

    final time = _selectedTime!;
    if (!_isWithinWorkingRange(time) || _bookedSlots.contains(time)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid available time slot.'),
        ),
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
                      'Time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_isOnline) ...[
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
                        'Available until $_closingTime',
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
                        itemCount: _timeSlots.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              mainAxisExtent: 34,
                            ),
                        itemBuilder: (context, index) {
                          final time = _timeSlots[index];
                          final isSelected = time == _selectedTime;
                          final isBooked = _bookedSlots.contains(time);

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
                    ] else ...[
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'Barber is currently offline',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
