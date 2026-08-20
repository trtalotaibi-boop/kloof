import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

import '../domain/riyadh_time.dart';
import 'my_bookings_screen.dart';

typedef BookingDocumentStreamFactory =
    Stream<Map<String, dynamic>?> Function(String bookingId);

class BookingConfirmationScreen extends StatefulWidget {
  final String bookingId;
  final BookingDocumentStreamFactory? bookingStream;
  final WidgetBuilder? myBookingsBuilder;

  const BookingConfirmationScreen({
    super.key,
    required this.bookingId,
    this.bookingStream,
    this.myBookingsBuilder,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  late Stream<Map<String, dynamic>?> _bookingStream;

  @override
  void initState() {
    super.initState();
    _bookingStream = _createBookingStream();
  }

  @override
  void didUpdateWidget(covariant BookingConfirmationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookingId != widget.bookingId ||
        oldWidget.bookingStream != widget.bookingStream) {
      _bookingStream = _createBookingStream();
    }
  }

  Stream<Map<String, dynamic>?> _createBookingStream() {
    final factory = widget.bookingStream;
    if (factory != null) return factory(widget.bookingId);
    return FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .map((snapshot) => snapshot.exists ? snapshot.data() : null);
  }

  String _formattedDate(Map<String, dynamic> booking, AppLocalizations l10n) {
    final timestamp = booking['slotStart'] ?? booking['bookingDate'];
    if (timestamp is! Timestamp) return l10n.myBookingsNotAvailable;
    return DateFormat.yMd(
      l10n.localeName,
    ).format(utcInstantToRiyadhWallClock(timestamp.toDate()));
  }

  String _formattedTime(Map<String, dynamic> booking, AppLocalizations l10n) {
    final slotStart = booking['slotStart'];
    if (slotStart is Timestamp) {
      return DateFormat.jm(
        l10n.localeName,
      ).format(utcInstantToRiyadhWallClock(slotStart.toDate()));
    }
    return booking['selectedTime']?.toString() ?? l10n.myBookingsNotAvailable;
  }

  String _formattedPrice(Map<String, dynamic> booking, AppLocalizations l10n) {
    final price = booking['servicePrice'];
    if (price is! num) return l10n.myBookingsNotAvailable;
    final priceText = price.toDouble() == price.toInt()
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
    return l10n.bookingConfirmationPriceValue(priceText);
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

  void _goToMyBookings() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: widget.myBookingsBuilder ?? (_) => const MyBookingsScreen(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToMyBookings();
      },
      child: Scaffold(
        backgroundColor: KloofColors.warmOffWhite,
        appBar: AppBar(
          leading: BackButton(
            onPressed: _goToMyBookings,
            color: KloofColors.primaryText,
          ),
          backgroundColor: KloofColors.warmOffWhite,
          elevation: 0,
          iconTheme: const IconThemeData(color: KloofColors.primaryText),
          title: Text(
            l10n.bookingConfirmationTitle,
            style: const TextStyle(color: KloofColors.primaryText),
          ),
        ),
        body: StreamBuilder<Map<String, dynamic>?>(
          stream: _bookingStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _messageState(l10n.bookingConfirmationLoadFailed);
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final booking = snapshot.data;
            if (booking == null) {
              return _messageState(l10n.bookingConfirmationNotFound);
            }
            return _successContent(booking, l10n);
          },
        ),
      ),
    );
  }

  Widget _messageState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: KloofColors.secondaryText),
        ),
      ),
    );
  }

  Widget _successContent(Map<String, dynamic> booking, AppLocalizations l10n) {
    final barberName = booking['barberName']?.toString().trim();
    final service = booking['service']?.toString().trim();
    final status = booking['status']?.toString() ?? 'pending';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Icon(
              Icons.check_circle_rounded,
              size: 92,
              color: KloofColors.success,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.bookingConfirmationReceivedTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: KloofColors.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.bookingConfirmationReceivedBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: KloofColors.secondaryText,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsetsDirectional.all(16),
              decoration: BoxDecoration(
                color: KloofColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _detailRow(
                    l10n.bookingConfirmationLabelBarber,
                    barberName == null || barberName.isEmpty
                        ? l10n.myBookingsUnknownBarber
                        : barberName,
                  ),
                  const SizedBox(height: 10),
                  _detailRow(
                    l10n.bookingConfirmationLabelService,
                    service == null || service.isEmpty
                        ? l10n.myBookingsNotAvailable
                        : _localizedServiceName(service, l10n),
                  ),
                  const SizedBox(height: 10),
                  _detailRow(
                    l10n.bookingConfirmationLabelPrice,
                    _formattedPrice(booking, l10n),
                  ),
                  const SizedBox(height: 10),
                  _detailRow(
                    l10n.bookingConfirmationLabelDate,
                    _formattedDate(booking, l10n),
                  ),
                  const SizedBox(height: 10),
                  _detailRow(
                    l10n.bookingConfirmationLabelTime,
                    _formattedTime(booking, l10n),
                  ),
                  const SizedBox(height: 10),
                  _detailRow(
                    l10n.bookingConfirmationLabelStatus,
                    _localizedStatusLabel(status, l10n),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goToMyBookings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KloofColors.primaryBlack,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l10n.bookingConfirmationDone,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: KloofColors.secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: KloofColors.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
