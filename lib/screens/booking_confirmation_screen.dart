import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  String _formattedDate(AppLocalizations l10n) {
    return DateFormat.yMd(l10n.localeName).format(selectedDate);
  }

  String _singleServiceLabel(AppLocalizations l10n) {
    final displayService = service
        .replaceAll('•', ',')
        .split(',')
        .map((item) => item.trim())
        .firstWhere((item) => item.isNotEmpty, orElse: () => service.trim());

    return _localizedServiceName(displayService, l10n);
  }

  String _formattedPrice(AppLocalizations l10n) {
    if (servicePrice == null) return '-';
    final isInt = servicePrice == servicePrice!.toInt();
    final priceText = isInt
        ? servicePrice!.toInt().toString()
        : servicePrice!.toStringAsFixed(2);
    return l10n.bookingConfirmationPriceValue(priceText);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          l10n.bookingConfirmationTitle,
          style: TextStyle(color: Colors.black),
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
                    _detailRow(l10n.bookingConfirmationLabelBarber, barberName),
                    const SizedBox(height: 10),
                    _detailRow(
                      l10n.bookingConfirmationLabelService,
                      _singleServiceLabel(l10n),
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
                      _formattedDate(l10n),
                    ),
                    const SizedBox(height: 10),
                    _detailRow(l10n.bookingConfirmationLabelTime, selectedTime),
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
}
