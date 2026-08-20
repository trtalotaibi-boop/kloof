import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

import '../domain/riyadh_time.dart';
import 'home_screen.dart';

typedef CustomerBookingsStreamFactory =
    Stream<List<Map<String, dynamic>>> Function(String customerId);

class MyBookingsScreen extends StatelessWidget {
  final String? customerId;
  final CustomerBookingsStreamFactory? bookingsStream;

  const MyBookingsScreen({super.key, this.customerId, this.bookingsStream});

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
    final date = utcInstantToRiyadhWallClock(timestamp.toDate());
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
      final name = (data?['fullName'] ?? data?['name'])?.toString();
      if (name != null && name.trim().isNotEmpty) {
        return name;
      }
    } catch (_) {
      // Fall through to default label.
    }

    return l10n.myBookingsUnknownBarber;
  }

  String _localizedServiceName(String rawName, AppLocalizations l10n) {
    final normalized = rawName.trim().toLowerCase();
    switch (normalized) {
      case 'haircut':
      case 'حلاقة الرأس':
        return l10n.serviceHaircut;
      case 'beard trim':
      case 'لحية trim':
      case 'حلاقة الدقن':
        return l10n.barberDetailsFallbackServiceBeardTrim;
      case 'haircut + beard':
      case 'حلاقة الرأس والدقن':
        return l10n.barberProfileServiceHaircutAndBeard;
      case 'full head shave (zero cut)':
      case 'حلاقة كاملة':
      case 'حلاقة الرأس بالمكينة':
        return l10n.barberProfileServiceFullHeadShaveZeroCut;
      case 'beard machine shave':
      case 'حلاقة الدقن بالمكينة':
        return l10n.barberProfileServiceBeardMachineShave;
      case 'kids haircut':
      case 'أطفال حلاقة الرأس':
      case 'حلاقة أطفال':
        return l10n.barberProfileServiceKidsHaircut;
    }

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

    return displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
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

  String _bookingTime(Map<String, dynamic> booking, AppLocalizations l10n) {
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
        final value = DateTime.utc(2000, 1, 1, minutes ~/ 60, minutes % 60);
        return DateFormat.jm(l10n.localeName).format(value);
      }
    }

    final fallback =
        booking['selectedTime']?.toString() ?? l10n.myBookingsNotAvailable;
    return _localizedBookingTime(fallback, l10n);
  }

  String _bookingPrice(Map<String, dynamic> booking, AppLocalizations l10n) {
    final price = booking['servicePrice'];
    if (price is! num) return l10n.myBookingsNotAvailable;
    final priceText = price.toDouble() == price.toInt()
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
    return l10n.bookingConfirmationPriceValue(priceText);
  }

  Stream<List<Map<String, dynamic>>> _bookingsFor(String customerId) {
    final factory = bookingsStream;
    if (factory != null) return factory(customerId);
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  void _goToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Widget _bookingCard(BuildContext context, Map<String, dynamic> booking) {
    final l10n = AppLocalizations.of(context);
    final barberId = (booking['barberId'] as String?) ?? '';
    final fallbackBarberName = booking['barberName'] as String?;
    final service =
        (booking['service'] as String?) ?? l10n.myBookingsNotAvailable;
    final localizedTime = _bookingTime(booking, l10n);
    final bookingDate = booking['bookingDate'] as Timestamp?;
    final status = (booking['status'] as String?) ?? 'pending';
    final localizedService = _localizedServiceName(service, l10n);

    return FutureBuilder<String>(
      future: _resolveBarberName(barberId, fallbackBarberName, l10n),
      builder: (context, snapshot) {
        final barberName =
            snapshot.data ?? fallbackBarberName ?? l10n.myBookingsLoading;

        return Card(
          color: KloofColors.cardBackground,
          margin: const EdgeInsetsDirectional.only(bottom: 12),
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barberName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: KloofColors.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.myBookingsValueRow(
                    l10n.myBookingsServiceLabel,
                    localizedService,
                  ),
                  style: const TextStyle(
                    color: KloofColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.myBookingsValueRow(
                    l10n.myBookingsDateLabel,
                    _formatDate(bookingDate, l10n),
                  ),
                  style: const TextStyle(
                    color: KloofColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.myBookingsValueRow(
                    l10n.myBookingsTimeLabel,
                    localizedTime,
                  ),
                  style: const TextStyle(
                    color: KloofColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.myBookingsValueRow(
                    l10n.bookingConfirmationLabelPrice,
                    _bookingPrice(booking, l10n),
                  ),
                  style: const TextStyle(
                    color: KloofColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsetsDirectional.symmetric(
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
    final effectiveCustomerId =
        customerId ?? FirebaseAuth.instance.currentUser?.uid;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToHome(context);
      },
      child: Scaffold(
        backgroundColor: KloofColors.warmOffWhite,
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => _goToHome(context),
            color: KloofColors.primaryText,
          ),
          backgroundColor: KloofColors.warmOffWhite,
          elevation: 0,
          iconTheme: const IconThemeData(color: KloofColors.primaryText),
          title: Text(
            l10n.myBookingsTitle,
            style: const TextStyle(color: KloofColors.primaryText),
          ),
        ),
        body: effectiveCustomerId == null
            ? Center(
                child: Text(
                  l10n.myBookingsEmpty,
                  style: TextStyle(
                    color: KloofColors.secondaryText,
                    fontSize: 16,
                  ),
                ),
              )
            : StreamBuilder<List<Map<String, dynamic>>>(
                stream: _bookingsFor(effectiveCustomerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        l10n.myBookingsLoadFailed,
                        style: TextStyle(color: KloofColors.secondaryText),
                      ),
                    );
                  }

                  final bookings = List<Map<String, dynamic>>.from(
                    snapshot.data ?? const [],
                  );
                  if (bookings.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.myBookingsEmpty,
                        style: TextStyle(
                          color: KloofColors.secondaryText,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  bookings.sort(
                    (a, b) => _createdAtDate(b).compareTo(_createdAtDate(a)),
                  );

                  return ListView.builder(
                    padding: const EdgeInsetsDirectional.all(16),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      return _bookingCard(context, bookings[index]);
                    },
                  );
                },
              ),
      ),
    );
  }
}
