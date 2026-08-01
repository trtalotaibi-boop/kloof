import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BarberBookingsScreen extends StatelessWidget {
  const BarberBookingsScreen({super.key});

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

  String _formatPrice(dynamic rawPrice) {
    if (rawPrice == null) return '-';

    if (rawPrice is num) {
      final value = rawPrice.toDouble();
      final isInt = value == value.toInt();
      final text = isInt ? value.toInt().toString() : value.toStringAsFixed(2);
      return '$text SAR';
    }

    final parsed = double.tryParse(rawPrice.toString());
    if (parsed == null) return '-';
    final isInt = parsed == parsed.toInt();
    final text = isInt ? parsed.toInt().toString() : parsed.toStringAsFixed(2);
    return '$text SAR';
  }

  DateTime _createdAtDate(Map<String, dynamic> booking) {
    final createdAt = booking['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
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

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Booking Requests',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: currentUser == null
          ? const Center(
              child: Text(
                'Barber is not signed in.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('barberId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Failed to load bookings.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No booking requests yet.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                final bookings =
                    docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
                      ..sort(
                        (a, b) =>
                            _createdAtDate(b).compareTo(_createdAtDate(a)),
                      );

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    final bookingId = booking['id']?.toString() ?? '';
                    final status = booking['status']?.toString() ?? 'pending';
                    final customerId = booking['customerId']?.toString() ?? '';
                    final customerName = booking['customerName']?.toString();
                    final service = booking['service']?.toString() ?? '-';
                    final price = _formatPrice(booking['servicePrice']);
                    final date = _formatDate(
                      booking['bookingDate'] as Timestamp?,
                    );
                    final time = booking['selectedTime']?.toString() ?? '-';
                    final isPending = status.toLowerCase() == 'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
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
                                          fontSize: 16,
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
                                    borderRadius: BorderRadius.circular(20),
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
                            const SizedBox(height: 4),
                            Text('Price: $price'),
                            const SizedBox(height: 4),
                            Text('Date: $date'),
                            const SizedBox(height: 4),
                            Text('Time: $time'),
                            if (isPending) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: bookingId.isEmpty
                                          ? null
                                          : () => _updateBookingStatus(
                                              bookingId,
                                              'accepted',
                                            ),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: bookingId.isEmpty
                                          ? null
                                          : () => _updateBookingStatus(
                                              bookingId,
                                              'rejected',
                                            ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
