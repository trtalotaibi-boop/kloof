import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';

class BookingSuccessScreen extends StatefulWidget {
  final String barberName;
  final String selectedDate;
  final String selectedTime;
  final String selectedService;
  final String notes;
  final String bookingId;

  const BookingSuccessScreen({
    super.key,
    required this.barberName,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedService,
    required this.notes,
    required this.bookingId,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
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

  @override
  void initState() {
    super.initState();
    // Auto-navigate to home after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: Icon(
                    Icons.check,
                    size: 50,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.bookingSuccessTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.bookingSuccessSubtitle,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(l10n.bookingConfirmationLabelBarber, widget.barberName),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      l10n.bookingConfirmationLabelService,
                      _localizedServiceName(widget.selectedService, l10n),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(l10n.bookingConfirmationLabelDate, widget.selectedDate),
                    const SizedBox(height: 12),
                    _buildDetailRow(l10n.bookingConfirmationLabelTime, widget.selectedTime),
                    if (widget.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(l10n.bookingSuccessLabelNotes, widget.notes),
                    ],
                    const SizedBox(height: 12),
                    _buildDetailRow(l10n.bookingSuccessLabelBookingId, widget.bookingId),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(l10n.bookingSuccessBackToHome),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.bookingSuccessRedirecting,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
