import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

typedef BookingStatusUpdater =
    Future<bool> Function(String bookingId, String status);

enum BarberBookingListState { loading, error, empty, data }

BarberBookingListState resolveBarberBookingListState({
  required ConnectionState connectionState,
  required bool hasError,
  required bool hasData,
  required bool isEmpty,
}) {
  if (hasError) return BarberBookingListState.error;
  if (connectionState == ConnectionState.waiting) {
    return BarberBookingListState.loading;
  }
  if (!hasData || isEmpty) return BarberBookingListState.empty;
  return BarberBookingListState.data;
}

class BarberBookingActions extends StatefulWidget {
  final String bookingId;
  final String status;
  final BookingStatusUpdater updateStatus;

  const BarberBookingActions({
    super.key,
    required this.bookingId,
    required this.status,
    required this.updateStatus,
  });

  @override
  State<BarberBookingActions> createState() => _BarberBookingActionsState();
}

class _BarberBookingActionsState extends State<BarberBookingActions> {
  bool _isUpdating = false;
  String? _awaitingStreamStatus;

  String get _normalizedStatus => widget.status.toLowerCase();
  bool get _isBusy => _isUpdating || _awaitingStreamStatus != null;

  @override
  void didUpdateWidget(covariant BarberBookingActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_awaitingStreamStatus == _normalizedStatus) {
      _awaitingStreamStatus = null;
    }
  }

  String _successMessage(String status, AppLocalizations l10n) {
    return switch (status) {
      'accepted' => l10n.barberBookingAcceptedSuccess,
      'rejected' => l10n.barberBookingRejectedSuccess,
      'completed' => l10n.barberBookingCompletedSuccess,
      _ => l10n.barberBookingStatusUpdatedSuccess,
    };
  }

  Future<bool> _confirmRejection(AppLocalizations l10n) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.barberBookingsRejectConfirmTitle),
            content: Text(l10n.barberBookingsRejectConfirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.barberBookingsRejectConfirmAction),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _requestStatus(
    String requestedStatus, {
    bool confirmRejection = false,
  }) async {
    if (_isBusy || widget.bookingId.isEmpty) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isUpdating = true;
    });

    if (confirmRejection) {
      final confirmed = await _confirmRejection(l10n);
      if (!mounted) return;
      if (!confirmed) {
        setState(() {
          _isUpdating = false;
        });
        return;
      }
    }

    try {
      final updated = await widget.updateStatus(
        widget.bookingId,
        requestedStatus,
      );
      if (!updated) throw StateError('Booking status was not updated.');
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
        _awaitingStreamStatus = _normalizedStatus == requestedStatus
            ? null
            : requestedStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_successMessage(requestedStatus, l10n))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUpdating = false;
        _awaitingStreamStatus = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.barberBookingStatusUpdateFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasActions =
        _normalizedStatus == 'pending' || _normalizedStatus == 'accepted';
    if (!hasActions) return const SizedBox.shrink();

    if (_isBusy) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: 10),
        child: Row(
          key: ValueKey('booking-loading-${widget.bookingId}'),
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(l10n.barberBookingUpdating),
          ],
        ),
      );
    }

    if (_normalizedStatus == 'accepted') {
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: 10),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: ValueKey('booking-complete-${widget.bookingId}'),
            onPressed: () => _requestStatus('completed'),
            child: Text(l10n.barberBookingsComplete),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 10),
      child: OverflowBar(
        spacing: 10,
        overflowSpacing: 8,
        alignment: MainAxisAlignment.end,
        overflowAlignment: OverflowBarAlignment.start,
        children: [
          OutlinedButton(
            key: ValueKey('booking-accept-${widget.bookingId}'),
            onPressed: () => _requestStatus('accepted'),
            style: OutlinedButton.styleFrom(
              foregroundColor: KloofColors.success,
              side: const BorderSide(color: KloofColors.success),
            ),
            child: Text(l10n.barberBookingsAccept),
          ),
          OutlinedButton(
            key: ValueKey('booking-reject-${widget.bookingId}'),
            onPressed: () => _requestStatus('rejected', confirmRejection: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: KloofColors.error,
              side: const BorderSide(color: KloofColors.error),
            ),
            child: Text(l10n.barberBookingsReject),
          ),
        ],
      ),
    );
  }
}
