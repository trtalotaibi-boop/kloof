import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';

import 'my_bookings_screen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final String barberName;
  final String service;
  final double? servicePrice;
  final DateTime selectedDate;
  final String selectedTime;

  const BookingConfirmationScreen({
    super.key,
    required this.barberName,
    required this.service,
    required this.servicePrice,
    required this.selectedDate,
    required this.selectedTime,
  });

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
        return rawName.trim();
    }
  }

  String _formattedPrice(AppLocalizations l10n) {
    if (servicePrice == null) return '-';
    final isWhole = servicePrice == servicePrice!.toInt();
    final price = isWhole
        ? servicePrice!.toInt().toString()
        : servicePrice!.toStringAsFixed(2);
    return l10n.bookingConfirmationPriceValue(price);
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
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
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formattedDate = MaterialLocalizations.of(context).formatFullDate(
      selectedDate,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          l10n.bookingConfirmationTitle,
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle_rounded,
                size: 92,
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.bookingConfirmationReceivedTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.bookingConfirmationReceivedBody,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsetsDirectional.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _detailRow(
                      l10n.bookingConfirmationLabelBarber,
                      barberName,
                    ),
                    const SizedBox(height: 10),
                    _detailRow(
                      l10n.bookingConfirmationLabelService,
                      _localizedServiceName(service, l10n),
                    ),
                    if (servicePrice != null) ...[
                      const SizedBox(height: 10),
                      _detailRow(
                        l10n.bookingConfirmationLabelPrice,
                        _formattedPrice(l10n),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _detailRow(
                      l10n.bookingConfirmationLabelDate,
                      formattedDate,
                    ),
                    const SizedBox(height: 10),
                    _detailRow(
                      l10n.bookingConfirmationLabelTime,
                      selectedTime,
                    ),
                    const SizedBox(height: 10),
                    _detailRow(
                      l10n.bookingConfirmationLabelStatus,
                      l10n.bookingConfirmationStatusPending,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyBookingsScreen(),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
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
      ),
    );
  }
}
