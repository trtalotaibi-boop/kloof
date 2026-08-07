import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';

import '../utils/barber_document_utils.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  DateTime _createdAtDate(Map<String, dynamic> booking) {
    final createdAt = booking['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

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

  String _localizedServiceName(String rawName, AppLocalizations l10n) {
    final normalized = rawName.trim().toLowerCase();
    switch (normalized) {
      case 'haircut':
      case 'حلاقة الرأس':
        return l10n.serviceHaircut;
      case 'beard':
      case 'beard trim':
      case 'حلاقة الدقن':
        return l10n.serviceBeard;
      case 'haircut + beard':
      case 'حلاقة الرأس والدقن':
        return l10n.barberProfileServiceHaircutAndBeard;
      case 'kids':
      case 'kids haircut':
      case 'حلاقة أطفال':
        return l10n.serviceKidsHaircut;
      case 'full head shave (zero cut)':
      case 'full head shave':
      case 'zero cut':
      case 'حلاقة كاملة (زيرو)':
      case 'حلاقة الرأس بالمكينة':
        return l10n.serviceFullHeadShave;
      default:
        return rawName.trim().isEmpty ? '-' : rawName.trim();
    }
  }

  String _formatDate(BuildContext context, Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return MaterialLocalizations.of(
      context,
    ).formatCompactDate(timestamp.toDate());
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
      final name = barberDisplayName(doc.data());
      if (name.trim().isNotEmpty) {
        return name;
      }
    } catch (_) {
      // Fall through to a neutral fallback.
    }

    return '-';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(BuildContext context, Map<String, dynamic> booking) {
    final l10n = AppLocalizations.of(context);
    final barberId = (booking['barberId'] as String?) ?? '';
    final fallbackBarberName = booking['barberName'] as String?;
    final service = (booking['service'] as String?) ?? '-';
    final selectedTime = (booking['selectedTime'] as String?) ?? '-';
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
                _detailRow(
                  l10n.myBookingsServiceLabel,
                  _localizedServiceName(service, l10n),
                ),
                _detailRow(
                  l10n.myBookingsDateLabel,
                  _formatDate(context, bookingDate),
                ),
                _detailRow(l10n.myBookingsTimeLabel, selectedTime),
                const SizedBox(height: 6),
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
        title: Text(
          l10n.myBookingsTitle,
          style: const TextStyle(color: Colors.black),
        ),
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
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.black54,
                      size: 32,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.barberDashboardNoBookings,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                final bookings = docs.map((doc) => doc.data()).toList()
                  ..sort(
                    (a, b) => _createdAtDate(b).compareTo(_createdAtDate(a)),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    return _bookingCard(context, bookings[index]);
                  },
                );
              },
            ),
    );
  }
}
