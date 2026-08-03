import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kloof/l10n/app_localizations.dart';

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

  String _formatPrice(dynamic rawPrice) {
    if (rawPrice == null) return '-';

    if (rawPrice is num) {
      final value = rawPrice.toDouble();
      final isInt = value == value.toInt();
      return isInt ? value.toInt().toString() : value.toStringAsFixed(2);
    }

    final parsed = double.tryParse(rawPrice.toString());
    if (parsed == null) return '-';
    final isInt = parsed == parsed.toInt();
    return isInt ? parsed.toInt().toString() : parsed.toStringAsFixed(2);
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

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          l10n.barberBookingsTitle,
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: currentUser == null
          ? Center(
              child: Text(
                l10n.barberBookingsSignedOut,
                style: const TextStyle(color: Colors.black54),
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
                  return Center(
                    child: Text(
                      l10n.barberBookingsLoadFailed,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.barberBookingsEmpty,
                      style: const TextStyle(color: Colors.black54),
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
                  padding: const EdgeInsetsDirectional.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    final bookingId = booking['id']?.toString() ?? '';
                    final status = booking['status']?.toString() ?? 'pending';
                    final customerId = booking['customerId']?.toString() ?? '';
                    final customerName = booking['customerName']?.toString();
                    final service = booking['service']?.toString() ?? '-';
                    final localizedService = _localizedServiceName(service, l10n);
                    final rawPrice = _formatPrice(booking['servicePrice']);
                    final price = rawPrice == '-'
                        ? rawPrice
                        : l10n.bookingConfirmationPriceValue(rawPrice);
                    final date = _formatDate(
                      booking['bookingDate'] as Timestamp?,
                      l10n,
                    );
                    final time = booking['selectedTime']?.toString() ?? '-';
                    final isPending = status.toLowerCase() == 'pending';

                    return Card(
                      margin: const EdgeInsetsDirectional.only(bottom: 12),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(14),
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
                                      l10n,
                                    ),
                                    builder: (context, nameSnapshot) {
                                      final displayName =
                                          nameSnapshot.data ?? l10n.barberBookingsCustomerFallback;
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
                            const SizedBox(height: 4),
                            Text(
                              l10n.myBookingsValueRow(
                                l10n.bookingConfirmationLabelPrice,
                                price,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.myBookingsValueRow(
                                l10n.myBookingsDateLabel,
                                date,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.myBookingsValueRow(
                                l10n.myBookingsTimeLabel,
                                time,
                              ),
                            ),
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
                                      child: Text(l10n.barberBookingsAccept),
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
                                      child: Text(l10n.barberBookingsReject),
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
