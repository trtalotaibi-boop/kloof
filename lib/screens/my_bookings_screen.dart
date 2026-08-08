import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';
import '../utils/barber_document_utils.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  Color _statusColor(String status) {
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

  String _localizedStatusLabel(String status, AppLocalizations l10n) {
    switch (status.toLowerCase()) {
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<String> _resolveBarberName(
    String barberId,
    String? fallbackName,
  ) async {
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName;
    }
    if (barberId.trim().isEmpty) {
      return '-';
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('barbers')
          .doc(barberId)
          .get();
      final data = doc.data();
      final name = barberDisplayName(data);
      if (name.trim().isNotEmpty) {
        return name;
      }
    } catch (_) {
      // Fall through to neutral fallback.
    }

    return '-';
  }

  Widget _bookingCard(BuildContext context, Map<String, dynamic> booking) {
    final l10n = AppLocalizations.of(context);
    final barberId = (booking['barberId'] as String?) ?? '';
    final fallbackBarberName = booking['barberName'] as String?;
    final service = (booking['service'] as String?) ?? 'N/A';
    final selectedTime = (booking['selectedTime'] as String?) ?? 'N/A';
    final bookingDate = booking['bookingDate'] as Timestamp?;
    final status = (booking['status'] as String?) ?? 'pending';

    return FutureBuilder<String>(
      future: _resolveBarberName(barberId, fallbackBarberName),
      builder: (context, snapshot) {
        final barberName = snapshot.data ?? fallbackBarberName ?? '...';

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barberName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.myBookingsServiceLabel}: $service',
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.myBookingsDateLabel}: ${_formatDate(bookingDate)}',
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.myBookingsTimeLabel}: $selectedTime',
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor(status)),
                    ),
                    child: Text(
                      _localizedStatusLabel(status, l10n),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(l10n.myBookingsTitle, style: const TextStyle(color: Colors.black)),
      ),
      body: user == null
          ? Center(
              child: Text(
                l10n.barberDashboardNoBookings,
                style: const TextStyle(color: Colors.black54, fontSize: 16),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('customerId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('MY_BOOKINGS_STREAM_ERROR: ${snapshot.error}');
                  return const Center(
                    child: Text(
                      'Failed to load bookings.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.barberDashboardNoBookings,
                      style: const TextStyle(color: Colors.black54, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _bookingCard(context, docs[index].data());
                  },
                );
              },
            ),
    );
  }
}
