import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kloof/l10n/app_localizations.dart';

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

  String _formatDate(Timestamp? timestamp, AppLocalizations l10n) {
    if (timestamp == null) return l10n.myBookingsNotAvailable;
    final date = timestamp.toDate();
    return DateFormat.yMd(l10n.localeName).format(date);
  }

  Future<String> _resolveBarberName(
    String barberId,
    String? fallbackName,
    AppLocalizations l10n,
  ) async {
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName;
    }
    if (barberId.trim().isEmpty) {
      return l10n.myBookingsUnknownBarber;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('barbers')
          .doc(barberId)
          .get();
      final data = doc.data();
      final name = data?['name'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        return name;
      }
    } catch (_) {
      // Fall through to default label.
    }

    return l10n.myBookingsUnknownBarber;
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

  String _toWesternDigits(String input) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    final buffer = StringBuffer();

    for (final char in input.split('')) {
      final index = arabicIndic.indexOf(char);
      buffer.write(index == -1 ? char : western[index]);
    }

    return buffer.toString();
  }

  String _localizedBookingTime(String rawTime, AppLocalizations l10n) {
    final original = rawTime.trim();
    if (original.isEmpty) return original;

    final normalized = _toWesternDigits(original)
        .replaceAll('ص', 'AM')
        .replaceAll('م', 'PM')
        .replaceAll(RegExp(r'\bam\b', caseSensitive: false), 'AM')
        .replaceAll(RegExp(r'\bpm\b', caseSensitive: false), 'PM')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const parsePatterns = <String>[
      'h:mm a',
      'hh:mm a',
      'a h:mm',
      'a hh:mm',
      'H:mm',
      'HH:mm',
    ];

    for (final pattern in parsePatterns) {
      try {
        final parsed = DateFormat(pattern, 'en').parseStrict(normalized);
        return DateFormat.jm(l10n.localeName).format(parsed);
      } catch (_) {
        // Keep trying known legacy formats.
      }
    }

    return rawTime;
  }

  Widget _bookingCard(BuildContext context, Map<String, dynamic> booking) {
    final l10n = AppLocalizations.of(context);
    final barberId = (booking['barberId'] as String?) ?? '';
    final fallbackBarberName = booking['barberName'] as String?;
    final service =
        (booking['service'] as String?) ?? l10n.myBookingsNotAvailable;
    final selectedTime =
        (booking['selectedTime'] as String?) ?? l10n.myBookingsNotAvailable;
    final localizedTime = _localizedBookingTime(selectedTime, l10n);
    final bookingDate = booking['bookingDate'] as Timestamp?;
    final status = (booking['status'] as String?) ?? 'pending';
    final localizedService = _localizedServiceName(service, l10n);

    return FutureBuilder<String>(
      future: _resolveBarberName(barberId, fallbackBarberName, l10n),
      builder: (context, snapshot) {
        final barberName =
            snapshot.data ?? fallbackBarberName ?? l10n.myBookingsLoading;

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
                  l10n.myBookingsValueRow(
                    l10n.myBookingsServiceLabel,
                    localizedService,
                  ),
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.myBookingsValueRow(
                    l10n.myBookingsDateLabel,
                    _formatDate(bookingDate, l10n),
                  ),
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.myBookingsValueRow(
                    l10n.myBookingsTimeLabel,
                    localizedTime,
                  ),
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
                l10n.myBookingsEmpty,
                style: TextStyle(color: Colors.black54, fontSize: 16),
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
                  return Center(
                    child: Text(
                      l10n.myBookingsLoadFailed,
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.myBookingsEmpty,
                      style: TextStyle(color: Colors.black54, fontSize: 16),
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
