import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

import '../data/booking_store.dart';
import '../domain/riyadh_time.dart';
import '../widgets/barber_booking_actions.dart';

class BarberBookingsScreen extends StatelessWidget {
  const BarberBookingsScreen({super.key});

  Color _statusChipColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return KloofColors.success;
      case 'rejected':
        return KloofColors.error;
      case 'completed':
        return KloofColors.mutedText;
      case 'pending':
      default:
        return KloofColors.warning;
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
    final date = utcInstantToRiyadhWallClock(timestamp.toDate());
    return DateFormat.yMd(l10n.localeName).format(date);
  }

  String _formatBookingTime(
    BuildContext context,
    Map<String, dynamic> booking,
    AppLocalizations l10n,
  ) {
    final slotStart = booking['slotStart'];
    if (slotStart is Timestamp) {
      return DateFormat.jm(
        l10n.localeName,
      ).format(utcInstantToRiyadhWallClock(slotStart.toDate()));
    }

    final rawMinutes = booking['selectedTimeMinutes'];
    if (rawMinutes is num) {
      final minutes = rawMinutes.toInt();
      if (minutes >= 0 && minutes < 24 * 60) {
        final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
        return MaterialLocalizations.of(context).formatTimeOfDay(time);
      }
    }

    final fallback = booking['selectedTime']?.toString().trim();
    return fallback == null || fallback.isEmpty ? '-' : fallback;
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
    String? fallbackName,
    AppLocalizations l10n,
  ) async {
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName;
    }

    return l10n.barberBookingsCustomerFallback;
  }

  Future<bool> _updateBookingStatus(String bookingId, String status) async {
    return BookingStore(
      FirebaseFirestore.instance,
    ).updateBookingStatus(bookingId, status);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: KloofColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: KloofColors.warmOffWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: KloofColors.primaryText),
        title: Text(
          l10n.barberBookingsTitle,
          style: TextStyle(color: KloofColors.primaryText),
        ),
      ),
      body: currentUser == null
          ? Center(
              child: Text(
                l10n.barberBookingsSignedOut,
                style: const TextStyle(color: KloofColors.secondaryText),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('barberId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final listState = resolveBarberBookingListState(
                  connectionState: snapshot.connectionState,
                  hasError: snapshot.hasError,
                  hasData: snapshot.hasData,
                  isEmpty: docs.isEmpty,
                );
                switch (listState) {
                  case BarberBookingListState.loading:
                    return const Center(child: CircularProgressIndicator());
                  case BarberBookingListState.error:
                    return Center(
                      child: Text(
                        l10n.barberBookingsLoadFailed,
                        style: const TextStyle(
                          color: KloofColors.secondaryText,
                        ),
                      ),
                    );
                  case BarberBookingListState.empty:
                    return Center(
                      child: Text(
                        l10n.barberBookingsEmpty,
                        style: const TextStyle(
                          color: KloofColors.secondaryText,
                        ),
                      ),
                    );
                  case BarberBookingListState.data:
                    break;
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
                    final customerName = booking['customerName']?.toString();
                    final service = booking['service']?.toString() ?? '-';
                    final localizedService = _localizedServiceName(
                      service,
                      l10n,
                    );
                    final rawPrice = _formatPrice(booking['servicePrice']);
                    final price = rawPrice == '-'
                        ? rawPrice
                        : l10n.bookingConfirmationPriceValue(rawPrice);
                    final date = _formatDate(
                      booking['bookingDate'] as Timestamp?,
                      l10n,
                    );
                    final time = _formatBookingTime(context, booking, l10n);

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
                            BarberBookingActions(
                              key: ValueKey('booking-actions-$bookingId'),
                              bookingId: bookingId,
                              status: status,
                              updateStatus: _updateBookingStatus,
                            ),
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
