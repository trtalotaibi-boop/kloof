import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';

class BarberSubscriptionScreen extends StatelessWidget {
  const BarberSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(l10n.barberSubscriptionTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.workspace_premium_outlined, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        l10n.barberSubscriptionPlanName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.barberSubscriptionPricePending,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(height: 32),
                      Text(l10n.barberSubscriptionFeatureProfile),
                      const SizedBox(height: 8),
                      Text(l10n.barberSubscriptionFeatureAvailability),
                      const SizedBox(height: 8),
                      Text(l10n.barberSubscriptionFeatureBookings),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.barberSubscriptionComingSoon)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.lock_outline),
                label: Text(l10n.barberSubscriptionPaymentAction),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.barberSubscriptionNoChargeNotice,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
